#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

readonly THRESHOLD=80
readonly LOG_FILE="$HOME/system_cleanup.log"
readonly -a TEMP_DIRS=("/tmp" "$HOME/.cache")

log() {
    local message="$1"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    if ! printf '%s - %s\n' "$timestamp" "$message" | tee -a "$LOG_FILE" >/dev/null; then
        printf '%s - %s\n' "$timestamp" "$message" >&2
    fi
}

check_disk_usage() {
    local usage
    usage="$(df -P / | awk 'NR==2 {gsub("%",""); print $5}')"

    log "Disk usage: ${usage}%"
    if (( usage > THRESHOLD )); then
        log "WARNING: Disk usage above ${THRESHOLD}%"
        return
    fi

    log "Disk usage is under control"
}

cleanup_temp_files() {
    local dir
    for dir in "${TEMP_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue

        log "Cleaning directory: $dir"
        (
            shopt -s dotglob nullglob
            local -a targets=("$dir"/*)
            if ((${#targets[@]})); then
                rm -rf -- "${targets[@]}"
            fi
        )
    done
    log "Temporary files cleanup completed"
}

log "===== System Cleanup Started ====="
check_disk_usage
cleanup_temp_files
log "===== System Cleanup Finished ====="
