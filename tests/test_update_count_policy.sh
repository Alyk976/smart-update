#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies.sh
source "./lib/policies.sh"

policy_update_count 50 100

[[ "$POLICY_DECISION" == "ALLOW" ]]
[[ -z "$POLICY_REASON" ]]

policy_update_count 150 100

[[ "$POLICY_DECISION" == "WARNING" ]]
[[ "$POLICY_REASON" == "Update count (150) exceeds limit (100)" ]]

printf "Tous les tests de la politique du nombre de mises a jour ont reussi.\n"
