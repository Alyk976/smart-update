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

config_validate_yes_no() {
    local variable_name="${1:-}"
    local value="${!variable_name-}"

    case "$value" in
        yes | no)
            return 0
            ;;
        *)
            printf 'Invalid %s value: %s\n' \
                "$variable_name" "${value:-undefined}" >&2
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
    config_validate_yes_no CHECK_ARCH_NEWS
}

config_validate_aur() {
    config_validate_yes_no ENABLE_AUR_UPDATES || return 1

    if [[ "${AUR_HELPER:-}" != "yay" ]]; then
        printf 'Invalid AUR_HELPER value: %s\n' \
            "${AUR_HELPER:-undefined}" >&2
        return 1
    fi

    if [[ "${AUR_USER:-}" != "auto"
        && ! "${AUR_USER:-}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        printf 'Invalid AUR_USER value: %s\n' \
            "${AUR_USER:-undefined}" >&2
        return 1
    fi

    if [[ "${AUR_USER:-}" == "root" ]]; then
        printf 'Invalid AUR_USER value: root\n' >&2
        return 1
    fi
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

    # Une valeur héritée de l'environnement ou d'un chargement précédent
    # ne doit pas masquer l'absence de ce paramètre obligatoire dans le fichier.
    unset ALLOW_CRITICAL_UPDATES ENABLE_AUR_UPDATES AUR_HELPER AUR_USER

    # shellcheck disable=SC1090
    source "$config_file"

    config_validate_mode || return 1
    config_validate_yes_no ALLOW_CRITICAL_UPDATES || return 1
    config_validate_aur || return 1
    config_validate_max_update_count || return 1
    config_validate_arch_news_enabled || return 1
    config_validate_arch_news_limit || return 1
}
