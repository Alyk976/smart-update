#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="critical_updates"
    POLICY_DETAILS=()
    CRITICAL_UPDATES=()

    local critical_file="${PROJECT_ROOT}/config/critical-packages.conf"

    if [[ ! -r "$critical_file" ]]; then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="Liste des paquets critiques absente."
        return
    fi

    local package_name

    for package_name in "${UPDATE_PACKAGES[@]}"; do
        if grep \
            --fixed-strings \
            --line-regexp \
            --quiet \
            "$package_name" \
            "$critical_file"; then

            CRITICAL_UPDATES+=("$package_name")
        fi
    done

    if ((${#CRITICAL_UPDATES[@]} == 0)); then
        POLICY_RESULT="ALLOW"
        POLICY_REASON="Aucune mise à jour critique détectée."
        return
    fi

    POLICY_RESULT="BLOCK"
    POLICY_REASON="Mises à jour critiques détectées :"
    POLICY_DETAILS=("${CRITICAL_UPDATES[@]}")
}
