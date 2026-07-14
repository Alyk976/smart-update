#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies.sh
source "./lib/policies.sh"

policy_disk_space 8192 4096

[[ "$POLICY_DECISION" == "ALLOW" ]]
[[ -z "$POLICY_REASON" ]]

policy_disk_space 1024 4096

[[ "$POLICY_DECISION" == "BLOCK" ]]
[[ "$POLICY_REASON" == \
"Insufficient disk space (1024 MiB available, 4096 MiB required)" ]]

printf "Tous les tests de la politique d'espace disque ont reussi.\n"
