#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="foreign_packages"
    POLICY_DETAILS=()

    local -a foreign_packages=()

    mapfile -t foreign_packages < <(
        pacman -Qqm 2>/dev/null || true
    )

    if ((${#foreign_packages[@]} == 0)); then
        POLICY_RESULT="ALLOW"
        POLICY_REASON="Aucun paquet étranger ou AUR installé."
        return
    fi

    POLICY_RESULT="WARNING"
    POLICY_REASON="${#foreign_packages[@]} paquet(s) étranger(s)/AUR détecté(s). Ils ne seront ni installés ni mis à jour par Smart Update."
    POLICY_DETAILS=("${foreign_packages[@]}")
}
