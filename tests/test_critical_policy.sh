#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

CONFIG_DIR="$TEST_DIR"
PROJECT_ROOT=$(pwd)
UPDATE_PACKAGES=(linux firefox)
CRITICAL_UPDATES=()

cat >"$TEST_DIR/critical-packages.conf" <<'CONF'
linux
systemd
openssh
CONF

run_policy() {
    unset -f policy_run 2>/dev/null || true
    # shellcheck source=lib/policies/20_critical_updates.sh
    source "./lib/policies/20_critical_updates.sh"
    policy_run
}

ALLOW_CRITICAL_UPDATES="no"
run_policy
[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "${POLICY_DETAILS[*]}" == "linux" ]]

ALLOW_CRITICAL_UPDATES="yes"
run_policy
[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "${POLICY_DETAILS[*]}" == "linux" ]]

UPDATE_PACKAGES=(firefox)
run_policy
[[ "$POLICY_RESULT" == "ALLOW" ]]
((${#POLICY_DETAILS[@]} == 0))

UPDATE_PACKAGES=(linux)
ALLOW_CRITICAL_UPDATES="maybe"
run_policy
[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "${POLICY_DETAILS[*]}" == "linux" ]]

UPDATE_PACKAGES=(firefox)
run_policy
[[ "$POLICY_RESULT" == "BLOCK" ]]
((${#POLICY_DETAILS[@]} == 0))

printf 'Tous les tests de la policy critical_updates ont réussi.\n'
