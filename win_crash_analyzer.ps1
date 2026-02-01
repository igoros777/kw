<#
.SYNOPSIS
  Analyze recent crash/freeze-related Windows events and correlate by type + timestamp.

.DESCRIPTION
  - Reads System and Application logs for a lookback window.
  - Chooses a "best" crash anchor using scoring (BugCheck > Kernel-Power > WHEA > volmgr > 6008 etc).
  - Correlates events in asymmetric windows (pre vs post) to reduce reboot noise.
  - Parses WHEA-Logger details (VEN/DEV/BDF/component/source).
  - Parses WER 1001 details (bucket/app/module/exception/report id) and de-dupes/group-summarizes.
  - Shows "last bad events before anchor" (often the real clue).

.PARAMETER LookbackHours
  How far back to scan logs.

.PARAMETER PreWindowMinutes
  Minutes BEFORE the anchor to include.

.PARAMETER PostWindowMinutes
  Minutes AFTER the anchor to include.

.PARAMETER MaxEventsPerLog
  Cap events read per log (keeps things snappy).

.PARAMETER OutDir
  Optional directory to export CSV outputs.

.PARAMETER EventId
  Optional Event ID to focus on (adds a dedicated analysis section).

.EXAMPLE
  Basic run with exports.

  .\win_crash_analyzer.ps1 -LookbackHours 6 -PreWindowMinutes 60 -PostWindowMinutes 5 -OutDir "$env:USERPROFILE\Desktop\CrashReport"

.EXAMPLE
  Exclude informational events from analysis.

  .\win_crash_analyzer.ps1 -LookbackHours 6 -PreWindowMinutes 60 -PostWindowMinutes 5 -ExcludeInformation -OutDir "$env:USERPROFILE\Desktop\CrashReport"

.EXAMPLE
  Focus analysis on a specific event ID.

  .\win_crash_analyzer.ps1 -LookbackHours 6 -PreWindowMinutes 60 -PostWindowMinutes 5 -ExcludeInformation -EventId 7034 -OutDir "$env:USERPROFILE\Desktop\CrashReport"

#>

[CmdletBinding()]
param(
  [int]$LookbackHours = 24,
  [int]$PreWindowMinutes = 30,
  [int]$PostWindowMinutes = 5,
  [int]$MaxEventsPerLog = 6000,
  [string]$OutDir = "",
  [switch]$ExcludeInformation,
  [int]$EventId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LevelName {
  param([int]$Level)
  switch ($Level) {
    1 { "Critical" }
    2 { "Error" }
    3 { "Warning" }
    4 { "Information" }
    5 { "Verbose" }
    default { "Level$Level" }
  }
}

function Get-NormalizedMessage {
  param([string]$Message)
  if ([string]::IsNullOrWhiteSpace($Message)) { return "" }
  return ($Message -replace "\s+", " ").Trim()
}

function Get-Events {
  param(
    [string[]]$LogNames,
    [datetime]$StartTime,
    [int]$MaxEvents
  )

  $all = foreach ($log in $LogNames) {
    try {
      Get-WinEvent -FilterHashtable @{ LogName = $log; StartTime = $StartTime } -MaxEvents $MaxEvents |
        Select-Object TimeCreated, LogName, Id, ProviderName, Level, Message
    } catch {
      Write-Warning "Failed reading log '$log': $($_.Exception.Message)"
    }
  }

  $all | Where-Object { $_ -and $_.PSObject.Properties['TimeCreated'] -and $_.TimeCreated } | Sort-Object TimeCreated
}

function Add-DerivedFields {
  param([object[]]$Events)

  $Events |
  Where-Object { $_ -and $_.PSObject.Properties['TimeCreated'] } |
  ForEach-Object {
    [PSCustomObject]@{
      TimeCreated  = $_.TimeCreated
      LogName      = $_.LogName
      Id           = $_.Id
      Provider     = $_.ProviderName
      Level        = $_.Level
      LevelName    = Get-LevelName $_.Level
      TypeKey      = "{0} | {1} | {2}" -f (Get-LevelName $_.Level), $_.ProviderName, $_.Id
      Message      = Get-NormalizedMessage $_.Message
    }
  }
}

function Get-AnchorScore {
  param(
    [string]$LogName,
    [string]$Provider,
    [int]$Id,
    [int]$Level,
    [string]$Message
  )

  # Higher = more anchor-worthy
  # Intentionally biased toward “real crash/hardware signals” over reboot chatter
  $score = 0

  # BugCheck (actual BSOD evidence)
  if (($Provider -eq "BugCheck" -and $Id -eq 1001) -or
      ($Provider -eq "Microsoft-Windows-WER-SystemErrorReporting" -and $Id -eq 1001 -and $Message -match "Bugcheck|BlueScreen|Stop code")) {
    $score = 100
  }

  # Kernel-Power 41 (unclean shutdown)
  if ($LogName -eq "System" -and $Provider -eq "Microsoft-Windows-Kernel-Power" -and $Id -eq 41) {
    $score = [Math]::Max($score, 90)
  }

  # WHEA hardware errors (often root cause for freezes)
  if ($Provider -eq "Microsoft-Windows-WHEA-Logger" -and $Id -in 1,17,18,19,20,47) {
    $score = [Math]::Max($score, 85)
  }

  # volmgr 161 (dump issues) useful signal
  if ($Provider -eq "volmgr" -and $Id -eq 161) {
    $score = [Math]::Max($score, 70)
  }

  # Unexpected shutdown 6008 (redundant, but ok)
  if ($LogName -eq "System" -and $Provider -eq "EventLog" -and $Id -eq 6008) {
    $score = [Math]::Max($score, 60)
  }

  # Display driver resets/hangs (can be key)
  if ($Provider -match "Display|nvlddmkm|amdkmdag|amdwddmg") {
    $score = [Math]::Max($score, 65)
  }

  # Disk/storage timeouts (can cause hard freezes)
  if ($Provider -match "Disk|storahci|stornvme|iaStor|iaStorAC|nvme|Ntfs") {
    $score = [Math]::Max($score, 55)
  }

  # General severity bias
  if ($Level -eq 1) { $score += 10 }  # Critical
  elseif ($Level -eq 2) { $score += 5 } # Error

  return $score
}

function Find-BestAnchor {
  param([object[]]$RawEvents)

  $candidates = $RawEvents | ForEach-Object {
    $msg = Get-NormalizedMessage $_.Message
    $score = Get-AnchorScore -LogName $_.LogName -Provider $_.ProviderName -Id $_.Id -Level $_.Level -Message $msg
    if ($score -gt 0) {
      [PSCustomObject]@{
        TimeCreated  = $_.TimeCreated
        LogName      = $_.LogName
        Id           = $_.Id
        ProviderName = $_.ProviderName
        Level        = $_.Level
        Score        = $score
        Message      = $msg
      }
    }
  } | Where-Object { $_ }

  if (-not $candidates) { return $null }

  # Pick the latest among the highest scores (sort by score desc then time desc)
  return $candidates | Sort-Object -Property Score, TimeCreated -Descending | Select-Object -First 1
}

function ConvertFrom-WheaMessage {
  param([string]$Message)

  if ([string]::IsNullOrWhiteSpace($Message)) { return $null }

  # Common fields in WHEA-Logger messages
  $component = $null
  $source = $null
  $primaryDev = $null
  $bdf = $null
  $ven = $null
  $dev = $null

  if ($Message -match "Component:\s*([^\.]+?)(?:\s{2,}|\sError|\sPrimary|\s$)") { $component = $Matches[1].Trim() }
  if ($Message -match "Error Source:\s*([^\.]+?)(?:\s{2,}|\sPrimary|\s$)") { $source = $Matches[1].Trim() }
  if ($Message -match "Primary Device Name:\s*([^\s]+)") { $primaryDev = $Matches[1].Trim() }

  # Sometimes BDF appears as "Primary Bus:Device:Function: 0x1:0x0:0x0"
  if ($Message -match "Primary Bus:Device:Function:\s*(0x[0-9A-Fa-f]+:0x[0-9A-Fa-f]+:0x[0-9A-Fa-f]+)") { $bdf = $Matches[1] }

  if ($primaryDev -match "VEN_([0-9A-Fa-f]{4})") { $ven = $Matches[1].ToUpper() }
  if ($primaryDev -match "DEV_([0-9A-Fa-f]{4})") { $dev = $Matches[1].ToUpper() }

  if (-not ($component -or $source -or $primaryDev -or $ven -or $dev -or $bdf)) { return $null }

  [PSCustomObject]@{
    Component     = $component
    ErrorSource   = $source
    PrimaryDevice = $primaryDev
    BDF           = $bdf
    VEN           = $ven
    DEV           = $dev
    DevKey        = if ($ven -and $dev) { "VEN_$ven&DEV_$dev" } else { "" }
  }
}

function ConvertFrom-Wer1001Message {
  param([string]$Message)

  if ([string]::IsNullOrWhiteSpace($Message)) { return $null }

  # WER 1001 payloads are "Problem signature: P1..P9" style; extract app/module/exception from those first.
  $msg = Get-NormalizedMessage $Message
  $bucket = $null
  $app = $null
  $module = $null
  $ex = $null
  $report = $null

  # Bucket appears as "Fault bucket <value>, type <n>" (value can be blank)
  if ($msg -match '(?i)Fault bucket\s*[:,\s]*([^,]+?)\s*,\s*type') {
    $bucket = $Matches[1].Trim()
    if ([string]::IsNullOrWhiteSpace($bucket)) { $bucket = $null }
  }

  if ($msg -match '(?i)Report Id\s*[:=]\s*([0-9A-Fa-f-]{8,})') { $report = $Matches[1].Trim() }

  # Pull P1..P9 into a map (non-greedy up to next P# or known section breaks)
  $sig = @{}
  $sigMatches = [regex]::Matches(
    $msg,
    '(?i)\bP([1-9])\s*[:=]\s*(.*?)(?=\s+P[1-9]\s*[:=]|\s+Additional information|\s+Extra information|\s+Attached files|$)'
  )
  foreach ($m in $sigMatches) {
    $sig["P$($m.Groups[1].Value)"] = $m.Groups[2].Value.Trim()
  }

  # Common WER signatures: P1=AppName, P4=ModuleName, P7=ExceptionCode
  if ($sig.ContainsKey("P1")) { $app = $sig["P1"] }
  if ($sig.ContainsKey("P4")) { $module = $sig["P4"] }
  if ($sig.ContainsKey("P7")) { $ex = $sig["P7"] }

  # Fallback to other wording if present
  if (-not $app -and $msg -match '(?i)Faulting application name\s*[:=]\s*([^,]+)') { $app = $Matches[1].Trim() }
  if (-not $module -and $msg -match '(?i)Faulting module name\s*[:=]\s*([^,]+)') { $module = $Matches[1].Trim() }
  if (-not $ex -and $msg -match '(?i)Exception code\s*[:=]\s*(0x[0-9A-Fa-f]+)') { $ex = $Matches[1].Trim() }

  if ($ex) {
    if ($ex -match '^[0-9A-Fa-f]{8}$') { $ex = ("0x{0}" -f $ex).ToLower() }
    elseif ($ex -match '^0x[0-9A-Fa-f]+$') { $ex = $ex.ToLower() }
  }

  # Some WER 1001 are “hardware error” style, still worth grouping.
  if (-not ($bucket -or $app -or $module -or $ex -or $report)) { return $null }

  [PSCustomObject]@{
    Bucket      = $bucket
    App         = $app
    Module      = $module
    Exception   = $ex
    ReportId    = $report
    WerKey      = ("{0}|{1}|{2}|{3}" -f $bucket, $app, $module, $ex).Trim('|')
  }
}

function Get-EventTypeSummary {
  param([object[]]$Events, [int]$Top = 25)

  $Events |
    Group-Object TypeKey |
    Sort-Object Count -Descending |
    Select-Object @{n="Count";e={$_.Count}}, @{n="Type";e={$_.Name}} |
    Select-Object -First $Top
}

function Add-SecondsFromAnchor {
  param([object[]]$Events, [datetime]$AnchorTime)

  $Events | ForEach-Object {
    $delta = [Math]::Abs((New-TimeSpan -Start $_.TimeCreated -End $AnchorTime).TotalSeconds)
    $_ | Add-Member -NotePropertyName SecondsFromAnchor -NotePropertyValue ([int]$delta) -Force
    $_
  }
}

function Limit-NearestPerType {
  param(
    [object[]]$Events,
    [int]$MaxPerType = 3
  )

  if (-not $Events) { return @() }

  $Events |
    Group-Object { "{0}|{1}" -f $_.Provider, $_.Id } |
    ForEach-Object {
      $_.Group | Sort-Object SecondsFromAnchor, TimeCreated | Select-Object -First $MaxPerType
    }
}

# --- Main ---
$start = (Get-Date).AddHours(-1 * $LookbackHours)

Write-Host ""
Write-Host "Reading events since $start (LookbackHours=$LookbackHours)..." -ForegroundColor Cyan

$raw = Get-Events -LogNames @("System","Application") -StartTime $start -MaxEvents $MaxEventsPerLog
$raw = if ($ExcludeInformation) { @($raw | Where-Object { $_.Level -ne 4 }) } else { $raw }
$events = @(Add-DerivedFields $raw)

if (-not $events -or $events.Count -eq 0) {
  Write-Host "No events found in the selected window." -ForegroundColor Yellow
  exit 0
}

$anchor = Find-BestAnchor $raw
if (-not $anchor) {
  Write-Host "No obvious crash anchor found in the last $LookbackHours hours." -ForegroundColor Yellow
  Write-Host "Showing recent Critical/Error anyway..." -ForegroundColor Yellow

  $events | Where-Object { $_.Level -in 1,2 } |
    Sort-Object TimeCreated -Descending |
    Select-Object -First 40 |
    Format-Table TimeCreated, LevelName, Provider, Id -Auto

  exit 0
}

$anchorTime = $anchor.TimeCreated
$fromRaw = $anchorTime.AddMinutes(-1 * $PreWindowMinutes)
$from = if ($fromRaw -lt $start) { $start } else { $fromRaw }
$to   = $anchorTime.AddMinutes($PostWindowMinutes)

Write-Host ""
Write-Host "Best crash anchor (scored):" -ForegroundColor Cyan
$anchor | Select-Object TimeCreated, LogName, Id, ProviderName, Level, Score, Message | Format-List

Write-Host ""
$preNote = ""
if ($from -gt $fromRaw) {
  $effectivePre = [int][Math]::Round((New-TimeSpan -Start $from -End $anchorTime).TotalMinutes)
  $preNote = " (pre truncated to ${effectivePre}m by lookback)"
}
Write-Host ("Correlating events between {0} and {1} (pre={2}m, post={3}m){4}..." -f $from, $to, $PreWindowMinutes, $PostWindowMinutes, $preNote) -ForegroundColor Cyan

$windowEvents = $events | Where-Object { $_.TimeCreated -ge $from -and $_.TimeCreated -le $to } | Sort-Object TimeCreated
$preEvents    = $windowEvents | Where-Object { $_.TimeCreated -lt $anchorTime }
$postEvents   = $windowEvents | Where-Object { $_.TimeCreated -ge $anchorTime }

Write-Host ""
Write-Host "Top event types BEFORE anchor:" -ForegroundColor Cyan
Get-EventTypeSummary -Events $preEvents -Top 25 | Format-Table -Auto

Write-Host ""
Write-Host "Top event types AFTER anchor:" -ForegroundColor Cyan
Get-EventTypeSummary -Events $postEvents -Top 25 | Format-Table -Auto

Write-Host ""
Write-Host "Nearest events to the anchor (by time distance):" -ForegroundColor Cyan
$nearestAll = Add-SecondsFromAnchor -Events $windowEvents -AnchorTime $anchorTime |
  Sort-Object SecondsFromAnchor, TimeCreated
$nearest = Limit-NearestPerType -Events $nearestAll -MaxPerType 3 |
  Sort-Object SecondsFromAnchor, TimeCreated |
  Select-Object -First 50
$nearest | Format-Table SecondsFromAnchor, TimeCreated, LevelName, Provider, Id -Auto

# --- Pre-anchor suspect events (GPU/storage/power) ---
$preSuspectsRegex = 'Display|TDR|nvlddmkm|amdkmdag|amdwddmg|dxgkrnl|igfx|GPU|graphics|Disk|storahci|stornvme|iaStor|iaStorAC|storport|nvme|Ntfs|volmgr|partmgr|Kernel-Power|Power-Troubleshooter|Kernel-Boot|Kernel-General|Sleep|ACPI|Processor-Power'
$preSuspects = @($preEvents | Where-Object { $_.Provider -match $preSuspectsRegex -or $_.Message -match $preSuspectsRegex })
$preSuspectsBad = @($preSuspects | Where-Object { $_.Level -in 1,2,3 } | Sort-Object TimeCreated -Descending)
$preSuspectsInfo = @($preSuspects | Where-Object { $_.Level -eq 4 } | Sort-Object TimeCreated -Descending)

Write-Host ""
Write-Host "Pre-anchor suspect events (GPU/display, storage timeouts, power/sleep) [Critical/Error/Warning first]:" -ForegroundColor Cyan
if ($preSuspectsBad.Count -gt 0) {
  $preSuspectsBad | Select-Object -First 40 | Format-Table TimeCreated, LevelName, Provider, Id, Message -Auto
} else {
  Write-Host "No suspect events at Critical/Error/Warning levels in the pre-anchor window." -ForegroundColor Yellow
}

if ($preSuspectsInfo.Count -gt 0) {
  Write-Host ""
  Write-Host "Related informational events (lower priority):" -ForegroundColor DarkGray
  $preSuspectsInfo | Select-Object -First 15 | Format-Table TimeCreated, LevelName, Provider, Id, Message -Auto
}

# --- Last bad events before anchor (often the best clue) ---
Write-Host ""
Write-Host "Last bad events BEFORE anchor (Critical/Error/Warning):" -ForegroundColor Cyan
$lastBad = $preEvents | Where-Object { $_.Level -in 1,2,3 } | Sort-Object TimeCreated -Descending | Select-Object -First 30
$lastBad | Format-Table TimeCreated, LevelName, Provider, Id -Auto

# --- Suspect-related events (focused) ---
$suspectsRegex = 'WHEA|Display|nvlddmkm|amdkmdag|amdwddmg|Disk|storahci|stornvme|volmgr|BugCheck|Kernel-Power|EventLog|Ntfs'
Write-Host ""
Write-Host "Suspect-related events in window (focused providers/messages):" -ForegroundColor Cyan
$suspects = $windowEvents | Where-Object { $_.Provider -match $suspectsRegex -or $_.Message -match $suspectsRegex } | Sort-Object TimeCreated
$suspects | Select-Object TimeCreated, LevelName, Provider, Id, Message | Format-Table TimeCreated, LevelName, Provider, Id -Auto

# --- Event ID focus (optional) ---
if ($EventId) {
  $focusEvents = @($windowEvents | Where-Object { $_.Id -eq $EventId })
  Write-Host ""
  Write-Host "Event ID focus: $EventId (within window)" -ForegroundColor Cyan
  if ($focusEvents.Count -gt 0) {
    Write-Host "Count: $($focusEvents.Count)" -ForegroundColor DarkGray
    $focusEvents |
      Group-Object Provider |
      Sort-Object Count -Descending |
      Select-Object @{n="Count";e={$_.Count}}, Name |
      Select-Object -First 10 |
      Format-Table -Auto

    Write-Host ""
    Write-Host "Latest $EventId entries:" -ForegroundColor Cyan
    $focusEvents | Sort-Object TimeCreated -Descending | Select-Object -First 20 |
      Format-Table TimeCreated, LevelName, Provider, Id, Message -Auto
  } else {
    Write-Host "No events with ID $EventId found in the selected window." -ForegroundColor Yellow
  }
}

# --- WHEA enrichment ---
$wheaParsed = @()
$whea = @($windowEvents | Where-Object { $_.Provider -eq "Microsoft-Windows-WHEA-Logger" })
if ($whea.Count -gt 0) {
  $wheaParsed = $whea | ForEach-Object {
    $p = ConvertFrom-WheaMessage $_.Message
    if ($p) {
      [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        LevelName   = $_.LevelName
        Id          = $_.Id
        Component   = $p.Component
        ErrorSource = $p.ErrorSource
        DevKey      = $p.DevKey
        VEN         = $p.VEN
        DEV         = $p.DEV
        BDF         = $p.BDF
        PrimaryDevice = $p.PrimaryDevice
      }
    }
  } | Where-Object { $_ }

  Write-Host ""
  Write-Host "WHEA details (parsed):" -ForegroundColor Cyan
  $wheaParsed | Sort-Object TimeCreated | Format-Table TimeCreated, Id, Component, ErrorSource, DevKey, BDF -Auto

  Write-Host ""
  Write-Host "WHEA grouped by device (VEN/DEV):" -ForegroundColor Cyan
  $wheaParsed | Where-Object { $_.DevKey } |
    Group-Object DevKey |
    Sort-Object Count -Descending |
    Select-Object @{n="Count";e={$_.Count}}, Name |
    Format-Table -Auto
}

# --- WER 1001 enrichment + de-dupe ---
$werParsed = @()
$wer = @($windowEvents | Where-Object { $_.Provider -eq "Windows Error Reporting" -and $_.Id -eq 1001 })
if ($wer.Count -gt 0) {
  $werParsed = @($wer | ForEach-Object {
    $p = ConvertFrom-Wer1001Message $_.Message
    if ($p) {
      [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        Bucket      = $p.Bucket
        App         = $p.App
        Module      = $p.Module
        Exception   = $p.Exception
        ReportId    = $p.ReportId
        WerKey      = $p.WerKey
      }
    }
  } | Where-Object { $_ })

  if ($werParsed.Count -gt 0) {
    Write-Host ""
    Write-Host "WER 1001 summary (de-duped/grouped by bucket/app/module/exception):" -ForegroundColor Cyan
    $werParsed |
      Group-Object WerKey |
      Sort-Object Count -Descending |
      Select-Object @{n="Count";e={$_.Count}}, Name |
      Select-Object -First 25 |
      Format-Table -Wrap

    Write-Host ""
    Write-Host "Top WER 1001 entries (latest 20):" -ForegroundColor Cyan
    $werParsed | Sort-Object TimeCreated -Descending | Select-Object -First 20 |
      Format-Table TimeCreated, App, Module, Exception, Bucket -Auto
  }
}

# --- Optional exports ---
if ($OutDir -and $OutDir.Trim().Length -gt 0) {
  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $summaryPrePath  = Join-Path $OutDir "crash_summary_pre_$stamp.csv"
  $summaryPostPath = Join-Path $OutDir "crash_summary_post_$stamp.csv"
  $windowPath      = Join-Path $OutDir "crash_window_events_$stamp.csv"
  $nearestPath     = Join-Path $OutDir "crash_nearest_events_$stamp.csv"
  $suspectsPath    = Join-Path $OutDir "crash_suspects_$stamp.csv"
  $wheaPath        = Join-Path $OutDir "crash_whea_$stamp.csv"
  $werPath         = Join-Path $OutDir "crash_wer1001_$stamp.csv"
  $anchorPath      = Join-Path $OutDir "crash_anchor_$stamp.csv"

  (Get-EventTypeSummary -Events $preEvents -Top 200)  | Export-Csv -NoTypeInformation -Path $summaryPrePath
  (Get-EventTypeSummary -Events $postEvents -Top 200) | Export-Csv -NoTypeInformation -Path $summaryPostPath
  $windowEvents | Export-Csv -NoTypeInformation -Path $windowPath
  $nearest | Export-Csv -NoTypeInformation -Path $nearestPath
  $suspects | Export-Csv -NoTypeInformation -Path $suspectsPath
  if ($wheaParsed) { $wheaParsed | Export-Csv -NoTypeInformation -Path $wheaPath }
  if ($werParsed)  { $werParsed  | Export-Csv -NoTypeInformation -Path $werPath }
  $anchor | Export-Csv -NoTypeInformation -Path $anchorPath

  Write-Host ""
  Write-Host "Exported CSVs to ${OutDir}:" -ForegroundColor Cyan
  Write-Host " - $anchorPath"
  Write-Host " - $summaryPrePath"
  Write-Host " - $summaryPostPath"
  Write-Host " - $windowPath"
  Write-Host " - $nearestPath"
  Write-Host " - $suspectsPath"
  if ($wheaParsed) { Write-Host " - $wheaPath" }
  if ($werParsed)  { Write-Host " - $werPath" }
}
