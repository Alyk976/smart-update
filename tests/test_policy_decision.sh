#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/decision.sh
source "./lib/decision.sh"

# shellcheck source=lib/policies.sh
source "./lib/policies.sh"

decision_reset
policy_reset

policy_set_decision "WARNING" "Major version detected"
policy_submit

[[ "$DECISION_FINAL" == "WARNING" ]]
[[ "${DECISION_REASONS[0]}" == "Major version detected" ]]

policy_set_decision "BLOCK" "Critical package detected"
policy_submit

[[ "$DECISION_FINAL" == "BLOCK" ]]
[[ "${DECISION_REASONS[1]}" == "Critical package detected" ]]

printf "Tous les tests d'integration policy/decision ont reussi.\n"
