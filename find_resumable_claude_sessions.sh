#!/bin/bash
#
# find_resumable_claude_sessions.sh
#
# Locate resumable Claude Code sessions under a given directory and print, for
# each one: a descriptive session title, the project folder, the system
# username, the session ID, the date of last use, and a ready-to-paste command
# to resume the session.
#
# Claude Code stores every session as a "<session-uuid>.jsonl" file inside
#   <home>/.claude/projects/<munged-cwd>/
# The real working directory is recorded in the "cwd" field inside the file.
#
# The title is taken from the first available of:
#   1. "customTitle" - a name you gave the session with /rename
#   2. "aiTitle"     - the title Claude Code generates (shown in /resume)
#   3. "summary"     - the summary record written by older Claude Code versions
#   4. the first prompt you typed in the session (truncated)
#
# Speed is a priority: the scan fans the per-file work out across all CPU cores
# with "xargs -P".
#
# Usage:
#   ./find_resumable_claude_sessions.sh <search-directory> [num-jobs]
#
# Examples:
#   ./find_resumable_claude_sessions.sh /home
#   ./find_resumable_claude_sessions.sh /home 32
#   ./find_resumable_claude_sessions.sh /Users
#

set -u

# ----------------------------------------------------------------------------
# Arguments
# ----------------------------------------------------------------------------
SEARCH_DIR="${1:-}"
JOBS="${2:-}"

if [[ -z "${SEARCH_DIR}" || ! -d "${SEARCH_DIR}" ]]; then
    echo "Usage: $0 <search-directory> [num-jobs]" >&2
    echo "       <search-directory> must be an existing directory." >&2
    exit 1
fi

# Default job count = number of CPU cores (fallback to 4 if nproc is missing).
if [[ -z "${JOBS}" ]]; then
    JOBS="$(nproc 2>/dev/null || echo 4)"
fi

# Maximum title length (characters) in the report.
TITLE_MAX=80
export TITLE_MAX

# ----------------------------------------------------------------------------
# Title helper
#
# Reads a raw JSON string body (no surrounding quotes) on stdin and prints it
# as a single tidy line: common escapes decoded, whitespace collapsed.
# ----------------------------------------------------------------------------
clean_title() {
    sed -e 's/\\[nrt]/ /g' \
        -e 's/\\"/"/g' \
        -e 's/\\\\/\\/g' \
        -e 's/[[:space:]][[:space:]]*/ /g' \
        -e 's/^ //' \
        -e 's/ $//'
}
export -f clean_title

# ----------------------------------------------------------------------------
# Per-file worker
#
# Runs once per session .jsonl file (invoked in parallel by xargs). Everything
# it needs is self-contained so it can be exported and run in a subshell.
# ----------------------------------------------------------------------------
process_session() {
    local file="$1"

    # Session ID is the file name without the .jsonl extension.
    local session_id
    session_id="$(basename "${file}" .jsonl)"

    # Owning user of the session file. Fall back to parsing the home path
    # (/home/<user>/... or /Users/<user>/...) if stat is unavailable.
    local user
    user="$(stat -c '%U' "${file}" 2>/dev/null)" \
        || user="$(stat -f '%Su' "${file}" 2>/dev/null)"
    if [[ -z "${user}" || "${user}" == "UNKNOWN" ]]; then
        user="$(printf '%s\n' "${file}" | sed -n 's#.*/\(home\|Users\)/\([^/]*\)/.*#\2#p')"
        [[ -z "${user}" ]] && user="unknown"
    fi

    # Real working directory: first "cwd" value inside the transcript. This is
    # the fast path (grep stops at the first match). If it is missing, decode
    # the munged parent directory name (dashes -> slashes) as a best effort.
    local directory
    directory="$(grep -m1 -o '"cwd":"[^"]*"' "${file}" 2>/dev/null \
                 | sed 's/^"cwd":"//; s/"$//; s/\\\\/\\/g; s/\\\//\//g')"
    if [[ -z "${directory}" ]]; then
        local munged
        munged="$(basename "$(dirname "${file}")")"
        directory="$(printf '%s\n' "${munged}" | sed 's#-#/#g')"
    fi

    # Folder name = last path component of the working directory.
    local folder
    folder="$(basename "${directory}")"

    # Descriptive title. One grep pass collects both /rename titles and AI
    # titles; the most recent of each wins, and a /rename title beats an AI one.
    local title titles
    titles="$(grep -E -o '"(customTitle|aiTitle)":"([^"\\]|\\.)*"' "${file}" 2>/dev/null)"
    title="$(printf '%s\n' "${titles}" | sed -n 's/^"customTitle":"\(.*\)"$/\1/p' | tail -n 1)"
    [[ -z "${title}" ]] && \
        title="$(printf '%s\n' "${titles}" | sed -n 's/^"aiTitle":"\(.*\)"$/\1/p' | tail -n 1)"

    # Older Claude Code versions wrote {"type":"summary","summary":"..."}.
    # Filter on the record type, since "summary" is a common key elsewhere.
    if [[ -z "${title}" ]]; then
        title="$(grep '"type":"summary"' "${file}" 2>/dev/null \
                 | grep -E -o '"summary":"([^"\\]|\\.)*"' \
                 | sed 's/^"summary":"//; s/"$//' | tail -n 1)"
    fi

    # Last resort: the first prompt the user actually typed. Skip meta lines,
    # tool results and subagent turns; skip wrapper messages like
    # <local-command-stdout>. A slash command (e.g. "/gstack-upgrade") is used
    # only if the session never had a plain-text prompt.
    if [[ -z "${title}" ]]; then
        title="$(grep '"type":"user"' "${file}" 2>/dev/null \
                 | grep -v -e '"isMeta":true' -e '"isSidechain":true' -e '"tool_result"' \
                 | awk '
                     match($0, /"content":"([^"\\]|\\.)*"/) {
                         s = substr($0, RSTART + 11, RLENGTH - 12)
                         if (match(s, /<command-name>[^<]*<\/command-name>/)) {
                             if (cmd == "") {
                                 cmd = substr(s, RSTART + 14, RLENGTH - 29)
                                 if (match(s, /<command-args>[^<]*<\/command-args>/))
                                     cmd = cmd " " substr(s, RSTART + 14, RLENGTH - 29)
                             }
                             next
                         }
                         if (s ~ /^</ || s == "") next
                         print s; found = 1; exit
                     }
                     END { if (!found && cmd != "") print cmd }')"
    fi

    title="$(printf '%s' "${title}" | clean_title)"
    if (( ${#title} > TITLE_MAX )); then
        title="${title:0:$((TITLE_MAX - 3))}..."
    fi
    # Never emit an empty field: tab is IFS whitespace, so "read" would
    # collapse an empty column and shift every later field.
    [[ -z "${title}" ]] && title="(untitled)"

    # Date of last use = file modification time.
    local last_used
    last_used="$(stat -c '%y' "${file}" 2>/dev/null | cut -d'.' -f1)" \
        || last_used="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "${file}" 2>/dev/null)"

    # Resume command in the requested format.
    local resume_cmd="sudo su - ${user} && cd ${directory} && IS_SANDBOX=1 claude --dangerously-skip-permissions --resume ${session_id}"

    # Emit one tab-separated record. Sorting/formatting happens after the join.
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${last_used}" "${title}" "${folder}" "${user}" "${session_id}" "${directory}" "${resume_cmd}"
}
export -f process_session

# ----------------------------------------------------------------------------
# Scan (parallel) and render
# ----------------------------------------------------------------------------
echo "Scanning '${SEARCH_DIR}' for resumable Claude sessions using ${JOBS} parallel jobs..." >&2

# Only session transcripts living under a ".claude/projects" tree are
# resumable, so restrict the find to those paths for speed and accuracy.
# Subagent transcripts (<session-uuid>/subagents/agent-*.jsonl) live in the
# same tree but cannot be resumed on their own, so leave them out.
results="$(
    find "${SEARCH_DIR}" -type f -name '*.jsonl' -path '*/.claude/projects/*' \
         ! -path '*/subagents/*' -print0 2>/dev/null \
        | xargs -0 -P "${JOBS}" -I {} bash -c 'process_session "$@"' _ {} \
        | sort
)"

if [[ -z "${results}" ]]; then
    echo "No resumable Claude sessions found under '${SEARCH_DIR}'." >&2
    exit 0
fi

count="$(printf '%s\n' "${results}" | grep -c .)"
echo "Found ${count} session(s)." >&2

# Human-readable report.
printf '%s\n' "${results}" | while IFS=$'\t' read -r last_used title folder user session_id directory resume_cmd; do
    echo "----------------------------------------------------------------------"
    echo "Title      : ${title}"
    echo "Folder     : ${folder}"
    echo "User       : ${user}"
    echo "Session ID : ${session_id}"
    echo "Last used  : ${last_used}"
    echo "Directory  : ${directory}"
    echo "Resume     : ${resume_cmd}"
done
echo "----------------------------------------------------------------------"
