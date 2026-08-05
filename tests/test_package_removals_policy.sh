#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies/50_package_removals.sh
source "./lib/policies/50_package_removals.sh"

declare -a PACKAGE_REMOVALS=()
ALLOW_REMOVALS="no"

policy_run

[[ "$POLICY_NAME" == "package_removals" ]]
[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Aucune suppression de paquet." ]]
((${#POLICY_DETAILS[@]} == 0))

PACKAGE_REMOVALS=(atk hwids)
ALLOW_REMOVALS="yes"

policy_run

[[ "$POLICY_NAME" == "package_removals" ]]
[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "$POLICY_REASON" == "2 suppression(s) de paquet(s) détectée(s)." ]]
((${#POLICY_DETAILS[@]} == 2))
[[ "${POLICY_DETAILS[0]}" == "atk" ]]
[[ "${POLICY_DETAILS[1]}" == "hwids" ]]

ALLOW_REMOVALS="no"

policy_run

[[ "$POLICY_NAME" == "package_removals" ]]
[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "2 suppression(s) de paquet(s) détectée(s)." ]]
((${#POLICY_DETAILS[@]} == 2))
[[ "${POLICY_DETAILS[0]}" == "atk" ]]
[[ "${POLICY_DETAILS[1]}" == "hwids" ]]

ALLOW_REMOVALS="invalid"

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Configuration ALLOW_REMOVALS invalide : invalid." ]]
((${#POLICY_DETAILS[@]} == 0))

printf "Tous les tests de la politique des suppressions ont réussi.\n"
