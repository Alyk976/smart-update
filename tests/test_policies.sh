#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies.sh
source "./lib/policies.sh"

policy_reset

[[ "$POLICY_DECISION" == "ALLOW" ]]
[[ -z "$POLICY_REASON" ]]

policy_set_decision "WARNING" "Too many packages"

[[ "$POLICY_DECISION" == "WARNING" ]]
[[ "$POLICY_REASON" == "Too many packages" ]]

policy_set_decision "BLOCK" "Critical package"

[[ "$POLICY_DECISION" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Critical package" ]]

if policy_set_decision "INVALID" "test" 2>/dev/null; then
    printf 'Erreur : décision invalide acceptée.\n' >&2
    exit 1
fi

printf 'Tous les tests du module policies ont réussi.\n'
