#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

CRITICAL_FILE="$TEST_DIR/critical-packages.conf"

cat > "$CRITICAL_FILE" <<'CONF'
linux
systemd
openssh
CONF

# shellcheck source=lib/policies.sh
source "./lib/policies.sh"

policy_critical_package "linux" "$CRITICAL_FILE"

[[ "$POLICY_DECISION" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Critical package detected: linux" ]]

policy_critical_package "firefox" "$CRITICAL_FILE"

[[ "$POLICY_DECISION" == "ALLOW" ]]
[[ -z "$POLICY_REASON" ]]

printf "Tous les tests de la politique des paquets critiques ont reussi.\n"
