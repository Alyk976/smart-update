#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies/70_overwrite_guard.sh
source "./lib/policies/70_overwrite_guard.sh"

ALLOW_OVERWRITE="no"
policy_run

[[ "$POLICY_NAME" == "overwrite_guard" ]]
[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Écrasement forcé de fichiers désactivé." ]]
((${#POLICY_DETAILS[@]} == 0))

ALLOW_OVERWRITE="yes"
policy_run

[[ "$POLICY_NAME" == "overwrite_guard" ]]
[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "L’utilisation de --overwrite est interdite par Smart Update." ]]
((${#POLICY_DETAILS[@]} == 0))

ALLOW_OVERWRITE="invalid"
policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Configuration ALLOW_OVERWRITE invalide : invalid." ]]
((${#POLICY_DETAILS[@]} == 0))

unset ALLOW_OVERWRITE
policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Configuration ALLOW_OVERWRITE invalide : undefined." ]]
((${#POLICY_DETAILS[@]} == 0))

printf "Tous les tests de la politique overwrite ont réussi.\n"
