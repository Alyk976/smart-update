#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="new_dependencies"
    POLICY_DETAILS=()

    if [[ -n "${NEW_PACKAGES_ERROR:-}" ]]; then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="${NEW_PACKAGES_ERROR}"
        return
    fi

    if ((${#NEW_PACKAGES[@]} == 0)); then
        POLICY_RESULT="ALLOW"
        POLICY_REASON="Aucun nouveau paquet ou nouvelle dépendance."
        return
    fi

    POLICY_DETAILS=("${NEW_PACKAGES[@]}")
    POLICY_REASON="${#NEW_PACKAGES[@]} nouveau(x) paquet(s) ou nouvelle(s) dépendance(s) détecté(s)."

    case "${ALLOW_NEW_DEPENDENCIES:-}" in
        yes)
            POLICY_RESULT="WARNING"
            ;;
        no)
            POLICY_RESULT="BLOCK"
            ;;
        *)
            POLICY_DETAILS=()
            POLICY_RESULT="BLOCK"
            POLICY_REASON="Configuration ALLOW_NEW_DEPENDENCIES invalide : ${ALLOW_NEW_DEPENDENCIES:-undefined}."
            ;;
    esac
}
