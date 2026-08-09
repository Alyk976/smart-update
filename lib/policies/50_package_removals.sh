#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="package_removals"
    POLICY_DETAILS=()

    if [[ -n "${PACKAGE_REMOVALS_ERROR:-}" ]]; then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="Impossible d'analyser les suppressions de paquets : ${PACKAGE_REMOVALS_ERROR}"
        return
    fi

    if ((${#PACKAGE_REMOVALS[@]} == 0)); then
        POLICY_RESULT="ALLOW"
        POLICY_REASON="Aucune suppression de paquet."
        return
    fi

    POLICY_DETAILS=("${PACKAGE_REMOVALS[@]}")
    POLICY_REASON="${#PACKAGE_REMOVALS[@]} suppression(s) de paquet(s) détectée(s)."

    case "${ALLOW_REMOVALS:-}" in
        yes)
            POLICY_RESULT="WARNING"
            ;;
        no)
            POLICY_RESULT="BLOCK"
            ;;
        *)
            POLICY_DETAILS=()
            POLICY_RESULT="BLOCK"
            POLICY_REASON="Configuration ALLOW_REMOVALS invalide : ${ALLOW_REMOVALS:-undefined}."
            ;;
    esac
}
