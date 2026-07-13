#!/usr/bin/env bash

#
# Smart Update v2
#
# Module : Logger
#
# Description :
# Journalisation centralisée de Smart Update.
#

logger_log() {
    local level="$1"
    shift

    local message="$*"
    local timestamp

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    printf '[%s] [%s] %s\n' \
        "$timestamp" \
        "$level" \
        "$message" |
        tee -a "$LOG_FILE"
}

logger_info() {
    logger_log "INFO" "$@"
}

logger_warning() {
    logger_log "WARNING" "$@"
}

logger_error() {
    logger_log "ERROR" "$@"
}

logger_success() {
    logger_log "SUCCESS" "$@"
}

logger_debug() {
    if [[ "${DEBUG:-no}" == "yes" ]]; then
        logger_log "DEBUG" "$@"
    fi
}

logger_blocked() {
    local reason="$*"

    logger_log "BLOCKED" "$reason"

    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$reason" >> "$BLOCKED_LOG"
}

logger_die() {
    logger_error "$@"
    exit 1
}
