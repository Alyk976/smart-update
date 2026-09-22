#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

REPORT_FILE="$TEST_DIR/report.txt"
REPORT_START_EPOCH=$(date +%s)
REPORT_FINALIZED="no"
MODE="audit"
DECISION_FINAL="ALLOW"
DECISION_TYPES=()
DECISION_REASONS=()
UPDATE_PACKAGES=()
CRITICAL_UPDATES=()
NEW_PACKAGES=()
OFFICIAL_RESULT="NO_UPDATES"
OFFICIAL_INSTALLED_COUNT=0
OFFICIAL_EXECUTION_CAPABILITY="AUTOMATIC"
TRANSACTION_QUESTIONS=()
AUR_RESULT="NO_UPDATES"
AUR_UPDATE_NAMES=()
AUR_APPROVED_PACKAGES=()
AUR_SKIPPED_UNSTABLE=()
UNKNOWN_FOREIGN_PACKAGES=()
AUR_INSTALLED_PACKAGES=()

logger_info() { :; }

pacman() {
    [[ "${1:-}" == "-Qmq" ]] || return 1
    return 1
}

# shellcheck source=lib/exit_codes.sh
source "./lib/exit_codes.sh"
# shellcheck source=lib/report.sh
source "./lib/report.sh"

: >"$REPORT_FILE"
report_finalize "$EXIT_OK"

grep -Fq 'Paquets étrangers/AUR   : 0' "$REPORT_FILE"
grep -Fq 'Code de sortie           : 0 (OK)' "$REPORT_FILE"
[[ "$REPORT_FINALIZED" == "yes" ]]

printf 'Le rapport accepte une liste vide de paquets Foreign.\n'
