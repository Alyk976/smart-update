#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="package_replacements"
    POLICY_DETAILS=()

    if [[ -n "${PACKAGE_REPLACEMENTS_ERROR:-}" ]]; then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="${PACKAGE_REPLACEMENTS_ERROR}"
        return
    fi

    if ((${#PACKAGE_REPLACEMENTS[@]} == 0)); then
        POLICY_RESULT="ALLOW"
        POLICY_REASON="Aucun remplacement de paquet."
        return
    fi

    POLICY_DETAILS=("${PACKAGE_REPLACEMENTS[@]}")
    POLICY_REASON="${#PACKAGE_REPLACEMENTS[@]} remplacement(s) de paquet(s) détecté(s)."

    case "${ALLOW_REPLACEMENTS:-}" in
        yes)
            POLICY_RESULT="WARNING"
            ;;
        no)
            POLICY_RESULT="BLOCK"
            ;;
        *)
            POLICY_DETAILS=()
            POLICY_RESULT="BLOCK"
            POLICY_REASON="Configuration ALLOW_REPLACEMENTS invalide : ${ALLOW_REPLACEMENTS:-undefined}."
            ;;
    esac
}
