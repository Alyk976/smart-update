#!/usr/bin/env bash

# ==========================================
# Smart Update
# Decision Engine
# ==========================================

DECISION_FINAL="ALLOW"
DECISION_TYPES=()
DECISION_REASONS=()

decision_reset() {
    DECISION_FINAL="ALLOW"
    DECISION_TYPES=()
    DECISION_REASONS=()
}

decision_add() {
    local decision="${1:-}"
    local reason="${2:-}"

    case "$decision" in
        ALLOW | WARNING | BLOCK)
            ;;
        *)
            printf 'Invalid decision: %s\n' "$decision" >&2
            return 1
            ;;
    esac

    if [[ -n "$reason" ]]; then
        DECISION_TYPES+=("$decision")
        DECISION_REASONS+=("$reason")
    fi

    case "$decision" in
        BLOCK)
            DECISION_FINAL="BLOCK"
            ;;
        WARNING)
            if [[ "$DECISION_FINAL" != "BLOCK" ]]; then
                DECISION_FINAL="WARNING"
            fi
            ;;
    esac
}

decision_allows_installation() {
    case "${DECISION_FINAL:-}" in
        ALLOW | WARNING)
            return 0
            ;;
        BLOCK)
            return 1
            ;;
        *)
            return 2
            ;;
    esac
}
