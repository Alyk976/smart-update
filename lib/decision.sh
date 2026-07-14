#!/usr/bin/env bash

# ==========================================
# Smart Update v2
# Decision Engine
# ==========================================

DECISION_FINAL="ALLOW"
DECISION_REASONS=()

decision_reset() {
    DECISION_FINAL="ALLOW"
    DECISION_REASONS=()
}

decision_add() {
    local decision="${1:-}"
    local reason="${2:-}"

    case "$decision" in
        ALLOW|WARNING|BLOCK)
            ;;
        *)
            printf 'Invalid decision: %s\n' "$decision" >&2
            return 1
            ;;
    esac

    [[ -n "$reason" ]] && DECISION_REASONS+=("$reason")

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
