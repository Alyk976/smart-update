#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies/80_new_dependencies.sh
source "./lib/policies/80_new_dependencies.sh"

declare -a NEW_PACKAGES=()
NEW_PACKAGES_ERROR=""
ALLOW_NEW_DEPENDENCIES="no"

policy_run

[[ "$POLICY_NAME" == "new_dependencies" ]]
[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Aucun nouveau paquet ou nouvelle dépendance." ]]
((${#POLICY_DETAILS[@]} == 0))

NEW_PACKAGES=(gexiv2-common)
ALLOW_NEW_DEPENDENCIES="yes"

policy_run

[[ "$POLICY_NAME" == "new_dependencies" ]]
[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "$POLICY_REASON" == "1 nouveau(x) paquet(s) ou nouvelle(s) dépendance(s) détecté(s)." ]]
((${#POLICY_DETAILS[@]} == 1))
[[ "${POLICY_DETAILS[0]}" == "gexiv2-common" ]]

ALLOW_NEW_DEPENDENCIES="no"

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "1 nouveau(x) paquet(s) ou nouvelle(s) dépendance(s) détecté(s)." ]]
((${#POLICY_DETAILS[@]} == 1))
[[ "${POLICY_DETAILS[0]}" == "gexiv2-common" ]]

ALLOW_NEW_DEPENDENCIES="invalid"

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Configuration ALLOW_NEW_DEPENDENCIES invalide : invalid." ]]
((${#POLICY_DETAILS[@]} == 0))

NEW_PACKAGES=()
NEW_PACKAGES_ERROR="Impossible de déterminer les nouvelles dépendances."
ALLOW_NEW_DEPENDENCIES="no"

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Impossible de déterminer les nouvelles dépendances." ]]
((${#POLICY_DETAILS[@]} == 0))

printf "Tous les tests de la politique des nouvelles dépendances ont réussi.\n"
