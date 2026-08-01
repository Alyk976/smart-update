#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="update_count"
    POLICY_DETAILS=()

    if ((${#UPDATE_PACKAGES[@]} > MAX_UPDATE_COUNT)); then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="${#UPDATE_PACKAGES[@]} mises à jour détectées ; limite autorisée : ${MAX_UPDATE_COUNT}."
        return
    fi

    POLICY_RESULT="ALLOW"
    POLICY_REASON="Nombre de mises à jour dans la limite autorisée."
}
