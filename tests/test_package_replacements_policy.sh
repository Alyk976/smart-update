#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies/60_package_replacements.sh
source "./lib/policies/60_package_replacements.sh"

declare -a PACKAGE_REPLACEMENTS=()
PACKAGE_REPLACEMENTS_ERROR=""
ALLOW_REPLACEMENTS="no"

policy_run

[[ "$POLICY_NAME" == "package_replacements" ]]
[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Aucun remplacement de paquet." ]]
((${#POLICY_DETAILS[@]} == 0))

PACKAGE_REPLACEMENTS=(
    "atk -> at-spi2-core"
    "hwids -> hwdata"
)
ALLOW_REPLACEMENTS="yes"

policy_run

[[ "$POLICY_NAME" == "package_replacements" ]]
[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "$POLICY_REASON" == "2 remplacement(s) de paquet(s) détecté(s)." ]]
((${#POLICY_DETAILS[@]} == 2))
[[ "${POLICY_DETAILS[0]}" == "atk -> at-spi2-core" ]]
[[ "${POLICY_DETAILS[1]}" == "hwids -> hwdata" ]]

ALLOW_REPLACEMENTS="no"

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "2 remplacement(s) de paquet(s) détecté(s)." ]]
((${#POLICY_DETAILS[@]} == 2))

ALLOW_REPLACEMENTS="invalid"

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Configuration ALLOW_REPLACEMENTS invalide : invalid." ]]
((${#POLICY_DETAILS[@]} == 0))

PACKAGE_REPLACEMENTS=()
PACKAGE_REPLACEMENTS_ERROR="Le collecteur de remplacements a échoué."
ALLOW_REPLACEMENTS="no"

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Le collecteur de remplacements a échoué." ]]
((${#POLICY_DETAILS[@]} == 0))

printf "Tous les tests de la politique des remplacements ont réussi.\n"
