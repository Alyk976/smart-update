#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="overwrite_guard"
    POLICY_DETAILS=()

    case "${ALLOW_OVERWRITE:-}" in
        no)
            POLICY_RESULT="ALLOW"
            POLICY_REASON="Écrasement forcé de fichiers désactivé."
            ;;
        yes)
            POLICY_RESULT="BLOCK"
            POLICY_REASON="L’utilisation de --overwrite est interdite par Smart Update."
            ;;
        *)
            POLICY_RESULT="BLOCK"
            POLICY_REASON="Configuration ALLOW_OVERWRITE invalide : ${ALLOW_OVERWRITE:-undefined}."
            ;;
    esac
}
