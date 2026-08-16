#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
REPORT_FILE="$TEST_DIR/report.txt"
REPORT_START_EPOCH=$(date +%s)
REPORT_FINALIZED="no"
MODE="guarded"
DECISION_FINAL="BLOCK"
DECISION_TYPES=()
DECISION_REASONS=()
UPDATE_PACKAGES=(linux)
CRITICAL_UPDATES=()
NEW_PACKAGES=()
OFFICIAL_RESULT="NOT_RUN"
OFFICIAL_INSTALLED_COUNT=0
OFFICIAL_EXECUTION_CAPABILITY="AUTOMATIC"
TRANSACTION_QUESTIONS=()
AUR_RESULT="FAILED"
AUR_HELPER_RECHECK_REQUIRED="no"
AUR_HELPER_POST_UPDATE_STATUS="NOT_CHECKED"
AUR_PHASE_ERROR="Identité AUR indisponible : AUR_USER=auto sans SUDO_USER non-root fiable."
AUR_UPDATE_NAMES=()
AUR_APPROVED_PACKAGES=()
AUR_SKIPPED_UNSTABLE=()
UNKNOWN_FOREIGN_PACKAGES=()
AUR_INSTALLED_PACKAGES=()

logger_info() { :; }
pacman() {
    [[ "${1:-}" == "-Qmq" ]]
}

# shellcheck source=lib/exit_codes.sh
source "./lib/exit_codes.sh"
# shellcheck source=lib/report.sh
source "./lib/report.sh"

: >"$REPORT_FILE"
report_finalize "$EXIT_AUR_DISCOVERY_FAILED"

grep -Fq 'Installed: 0' "$REPORT_FILE"
grep -Fq 'Result   : NOT_RUN' "$REPORT_FILE"
grep -Fq 'Result                 : FAILED' "$REPORT_FILE"
grep -Fq 'Failed                 : Identité AUR indisponible' "$REPORT_FILE"
grep -Fq 'Detail                 : Identité AUR indisponible' "$REPORT_FILE"
grep -Fq 'Code de sortie           : 31 (AUR_DISCOVERY_FAILED)' "$REPORT_FILE"

printf "Le rapport d’échec d’identité AUR a été validé.\n"
