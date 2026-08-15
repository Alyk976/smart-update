#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
REPORT_FILE="$TEST_DIR/report.txt"
REPORT_START_EPOCH=$(date +%s)
REPORT_FINALIZED="no"
MODE="guarded"
DECISION_FINAL="WARNING"
DECISION_TYPES=(WARNING)
DECISION_REASONS=("Suppression acceptable selon la policy.")
UPDATE_PACKAGES=(qemu-common)
CRITICAL_UPDATES=()
NEW_PACKAGES=(gexiv2-common)
OFFICIAL_RESULT="MANUAL_TRANSACTION_REQUIRED"
OFFICIAL_INSTALLED_COUNT=0
OFFICIAL_EXECUTION_CAPABILITY="MANUAL_REQUIRED"
TRANSACTION_QUESTIONS=(
    'CONFLICT_PKG|qemu-common|11.1.0-1|qemu-block-gluster|11.0.3-1'
)
AUR_RESULT="DEFERRED_OFFICIAL_UPDATE_REQUIRED"
AUR_PHASE_ERROR="Official update requires manual package-manager decisions."
AUR_UPDATE_NAMES=(google-chrome)
AUR_APPROVED_PACKAGES=(google-chrome)
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
report_finalize "$EXIT_MANUAL_TRANSACTION_REQUIRED"

grep -Fq 'Policy decision             : WARNING' "$REPORT_FILE"
grep -Fq 'Official execution capability: MANUAL_REQUIRED' "$REPORT_FILE"
grep -Fq 'Result   : MANUAL_TRANSACTION_REQUIRED' "$REPORT_FILE"
grep -Fq 'Installed: 0' "$REPORT_FILE"
grep -Fq 'Manual reason               : CONFLICT_PKG|qemu-common|11.1.0-1|qemu-block-gluster|11.0.3-1' "$REPORT_FILE"
grep -Fq 'Result                 : DEFERRED_OFFICIAL_UPDATE_REQUIRED' "$REPORT_FILE"
grep -Fq 'Installed              : 0' "$REPORT_FILE"
grep -Fq 'Code de sortie           : 34 (MANUAL_TRANSACTION_REQUIRED)' "$REPORT_FILE"

printf 'Tous les tests du rapport de transaction manuelle ont réussi.\n'
