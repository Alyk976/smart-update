#!/usr/bin/env bash
# shellcheck disable=SC2034

AUR_CONTEXT_ERROR=""
declare -a AUR_FOREIGN_PACKAGES=()
declare -a UNKNOWN_FOREIGN_PACKAGES=()

aur_context_collect() {
    local helper="${1:-}" package output status response_repository response_name
    local -a foreign_packages=()
    AUR_CONTEXT_ERROR=""
    AUR_FOREIGN_PACKAGES=()
    UNKNOWN_FOREIGN_PACKAGES=()

    mapfile -t foreign_packages < <(pacman -Qqm 2>/dev/null || true)
    for package in "${foreign_packages[@]}"; do
        if output=$(aur_user_run "$helper" -Si --aur --color never "$package" 2>&1); then
            response_repository=$(awk -F: '/^Repository[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' <<<"$output")
            response_name=$(awk -F: '/^Name[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' <<<"$output")
            if [[ "$response_repository" != "aur" || "$response_name" != "$package" ]]; then
                AUR_CONTEXT_ERROR="Réponse AUR incohérente pour ${package}."
                AUR_FOREIGN_PACKAGES=()
                UNKNOWN_FOREIGN_PACKAGES=()
                return 1
            fi
            AUR_FOREIGN_PACKAGES+=("$package")
            continue
        else
            status=$?
        fi
        if ((status == 1)) \
            && grep -Fqx " -> No AUR package found for ${package}" <<<"$output"; then
            UNKNOWN_FOREIGN_PACKAGES+=("$package")
            continue
        fi
        AUR_CONTEXT_ERROR="Impossible de classifier le paquet Foreign ${package} : ${output}"
        AUR_FOREIGN_PACKAGES=()
        UNKNOWN_FOREIGN_PACKAGES=()
        return 1
    done
}
