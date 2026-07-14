#!/usr/bin/env bash

# ==========================================
# Smart Update v2
# Policy Engine
# ==========================================

POLICY_DECISION="ALLOW"
POLICY_REASON=""

policy_reset() {
    POLICY_DECISION="ALLOW"
    POLICY_REASON=""
}

policy_set_decision() {
    local decision="${1:-}"
    local reason="${2:-}"

    case "$decision" in
        ALLOW|WARNING|BLOCK)
            POLICY_DECISION="$decision"
            POLICY_REASON="$reason"
            ;;
        *)
            printf 'Invalid policy decision: %s\n' "$decision" >&2
            return 1
            ;;
    esac
}

policy_check() {
    policy_reset
}

policy_submit() {
    if ! declare -F decision_add >/dev/null 2>&1; then
        printf 'Decision engine is not loaded.\n' >&2
        return 1
    fi

    decision_add "$POLICY_DECISION" "$POLICY_REASON"
}

policy_critical_package() {
    local package_name="${1:-}"
    local critical_file="${2:-}"

    if [[ -z "$package_name" || -z "$critical_file" ]]; then
        printf 'Package name and critical package file are required.\n' >&2
        return 1
    fi

    if [[ ! -r "$critical_file" ]]; then
        printf 'Critical package file is missing or unreadable: %s\n' \
            "$critical_file" >&2
        return 1
    fi

    policy_reset

    if grep --fixed-strings --line-regexp --quiet \
        "$package_name" "$critical_file"; then

        policy_set_decision \
            "BLOCK" \
            "Critical package detected: ${package_name}"
    fi
}

policy_update_count() {
    local update_count="${1:-0}"
    local max_count="${2:-0}"

    if (( update_count > max_count )); then
        policy_set_decision \
            "WARNING" \
            "Update count (${update_count}) exceeds limit (${max_count})"
    else
        policy_reset
    fi
}

policy_disk_space() {
    local free_mib="${1:-0}"
    local minimum_mib="${2:-0}"

    if (( free_mib < minimum_mib )); then
        policy_set_decision \
            "BLOCK" \
            "Insufficient disk space (${free_mib} MiB available, ${minimum_mib} MiB required)"
    else
        policy_reset
    fi
}
