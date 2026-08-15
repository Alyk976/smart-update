#!/usr/bin/env bash

# ==========================================
# Smart Update
# Configuration Module
# ==========================================

config_validate_mode() {
    case "${MODE:-}" in
        audit | guarded)
            return 0
            ;;
        *)
            printf 'Invalid MODE value: %s\n' \
                "${MODE:-undefined}" >&2
            return 1
            ;;
    esac
}

config_validate_max_update_count() {
    if [[ ! "${MAX_UPDATE_COUNT:-}" =~ ^[0-9]+$ ]] \
        || ((MAX_UPDATE_COUNT <= 0)); then

        printf 'Invalid MAX_UPDATE_COUNT value: %s\n' \
            "${MAX_UPDATE_COUNT:-undefined}" >&2
        return 1
    fi
}

config_validate_arch_news_enabled() {
    case "${CHECK_ARCH_NEWS:-}" in
        yes | no)
            return 0
            ;;
        *)
            printf 'Invalid CHECK_ARCH_NEWS value: %s\n' \
                "${CHECK_ARCH_NEWS:-undefined}" >&2
            return 1
            ;;
    esac
}

config_validate_arch_news_limit() {
    if [[ ! "${ARCH_NEWS_LIMIT:-}" =~ ^[0-9]+$ ]] \
        || ((ARCH_NEWS_LIMIT <= 0)); then

        printf 'Invalid ARCH_NEWS_LIMIT value: %s\n' \
            "${ARCH_NEWS_LIMIT:-undefined}" >&2
        return 1
    fi
}

config_load() {
    local config_file="${1:-}"

    if [[ -z "$config_file" ]]; then
        printf 'Configuration path is required.\n' >&2
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        printf 'Configuration file is missing or unreadable: %s\n' \
            "$config_file" >&2
        return 1
    fi

    # shellcheck disable=SC1090
    source "$config_file"

    config_validate_mode || return 1
    config_validate_max_update_count || return 1
    config_validate_arch_news_enabled || return 1
    config_validate_arch_news_limit || return 1
}
