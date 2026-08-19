#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="foreign_packages"
    POLICY_DETAILS=()

    if [[ -n "${AUR_CONTEXT_ERROR:-}" ]]; then
        POLICY_RESULT="WARNING"
        POLICY_REASON="Classification AUR/Foreign indisponible."
        POLICY_DETAILS=("$AUR_CONTEXT_ERROR")
        return
    fi

    if ((${#UNKNOWN_FOREIGN_PACKAGES[@]} == 0)); then
        POLICY_RESULT="ALLOW"
        POLICY_REASON="Aucun paquet Foreign inconnu détecté."
        return
    fi

    POLICY_RESULT="WARNING"
    if [[ "${AUR_RESULT:-}" == "DISABLED" ]]; then
        POLICY_REASON="${#UNKNOWN_FOREIGN_PACKAGES[@]} paquet(s) Foreign détecté(s). Recherche AUR désactivée ; classification AUR non effectuée. Aucune modification automatique."
    else
        POLICY_REASON="${#UNKNOWN_FOREIGN_PACKAGES[@]} paquet(s) Foreign absent(s) de l'AUR. Aucune modification automatique."
    fi
    POLICY_DETAILS=("${UNKNOWN_FOREIGN_PACKAGES[@]}")
}
