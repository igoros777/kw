#!/bin/bash
#
# find_resumable_claude_sessions.sh
#
# Locate resumable Claude Code sessions under a given directory and print, for
# each one: the project folder, the system username, the session ID, the date
# of last use, and a ready-to-paste command to resume the session.
#
# Claude Code stores every session as a "<session-uuid>.jsonl" file inside
#   <home>/.claude/projects/<munged-cwd>/
# The real working directory is recorded in the "cwd" field inside the file.
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

    # Date of last use = file modification time.
    local last_used
    last_used="$(stat -c '%y' "${file}" 2>/dev/null | cut -d'.' -f1)" \
        || last_used="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "${file}" 2>/dev/null)"

    # Resume command in the requested format.
    local resume_cmd="sudo su - ${user} && cd ${directory} && IS_SANDBOX=1 claude --dangerously-skip-permissions --resume ${session_id}"

    # Emit one tab-separated record. Sorting/formatting happens after the join.
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${last_used}" "${folder}" "${user}" "${session_id}" "${directory}" "${resume_cmd}"
}
export -f process_session

# ----------------------------------------------------------------------------
# Scan (parallel) and render
# ----------------------------------------------------------------------------
echo "Scanning '${SEARCH_DIR}' for resumable Claude sessions using ${JOBS} parallel jobs..." >&2

# Only session transcripts living under a ".claude/projects" tree are
# resumable, so restrict the find to those paths for speed and accuracy.
results="$(
    find "${SEARCH_DIR}" -type f -name '*.jsonl' -path '*/.claude/projects/*' -print0 2>/dev/null \
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
printf '%s\n' "${results}" | while IFS=$'\t' read -r last_used folder user session_id directory resume_cmd; do
    echo "----------------------------------------------------------------------"
    echo "Folder     : ${folder}"
    echo "User       : ${user}"
    echo "Session ID : ${session_id}"
    echo "Last used  : ${last_used}"
    echo "Directory  : ${directory}"
    echo "Resume     : ${resume_cmd}"
done
echo "----------------------------------------------------------------------"
