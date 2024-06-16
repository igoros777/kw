@echo off
setlocal

:: Default backup base path
set "BackupBase=D:\BackupSD"
set "SourceDrive=F:"

:: Check if command line arguments are provided for backup base path and source drive
if not "%~1"=="" set "BackupBase=%~1"
if not "%~2"=="" set "SourceDrive=%~2"

:: Get current date
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "datestamp=%dt:~0,8%"

:: Get the current label of the drive
for /f "tokens=2 delims==" %%i in ('wmic volume where "DriveLetter='%SourceDrive%'" get Label /value') do set label=%%i

:: Check if the label is empty
if "%label%"=="" (
    label %SourceDrive% sd_%datestamp%
    set "Label=sd_%datestamp%"
)

:: Display the new label
echo Drive %SourceDrive% is labeled as %Label%

:: Create directory if it does not exist
if not exist "%BackupBase%\%Label%" (
    mkdir "%BackupBase%\%Label%"
)

:: Run robocopy with the new or existing label
robocopy %SourceDrive%\ "%BackupBase%\%Label%" /MIR /R:5 /W:5

endlocal
