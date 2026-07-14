#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/decision.sh
source "./lib/decision.sh"

decision_reset

[[ "$DECISION_FINAL" == "ALLOW" ]]
[[ "${#DECISION_REASONS[@]}" -eq 0 ]]

decision_add "WARNING" "Major version detected"

[[ "$DECISION_FINAL" == "WARNING" ]]
[[ "${#DECISION_REASONS[@]}" -eq 1 ]]
[[ "${DECISION_REASONS[0]}" == "Major version detected" ]]

decision_add "ALLOW" "Routine package update"

[[ "$DECISION_FINAL" == "WARNING" ]]
[[ "${#DECISION_REASONS[@]}" -eq 2 ]]

decision_add "BLOCK" "Critical package detected"

[[ "$DECISION_FINAL" == "BLOCK" ]]
[[ "${#DECISION_REASONS[@]}" -eq 3 ]]
[[ "${DECISION_REASONS[2]}" == "Critical package detected" ]]

decision_add "WARNING" "Another warning"

[[ "$DECISION_FINAL" == "BLOCK" ]]

if decision_add "INVALID" "test" 2>/dev/null; then
    printf 'Erreur : une décision invalide a été acceptée.\n' >&2
    exit 1
fi

printf 'Tous les tests du module decision ont réussi.\n'
