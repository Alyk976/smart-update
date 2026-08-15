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
DECISION_REASONS=("Mise à jour critique stable autorisée.")
UPDATE_PACKAGES=(linux glibc firefox)
CRITICAL_UPDATES=(linux)
NEW_PACKAGES=()
OFFICIAL_RESULT="INSTALLED"
OFFICIAL_INSTALLED_COUNT=3
AUR_RESULT="DEFERRED_HELPER_INCOMPATIBLE"
AUR_HELPER_RECHECK_REQUIRED="yes"
AUR_HELPER_POST_UPDATE_STATUS="INCOMPATIBLE"
AUR_PHASE_ERROR="Official update succeeded; AUR deferred because yay is incompatible or unavailable after the official libalpm update."
AUR_UPDATE_NAMES=(google-chrome visual-studio-code-bin foo-git bar-beta)
AUR_APPROVED_PACKAGES=(google-chrome visual-studio-code-bin)
AUR_SKIPPED_UNSTABLE=('foo-git|2-1|paquet VCS' 'bar-beta|2.0-beta1|version pré-release')
UNKNOWN_FOREIGN_PACKAGES=(private-local)
AUR_INSTALLED_PACKAGES=()

logger_info() { :; }
pacman() {
    [[ "${1:-}" == "-Qmq" ]] && printf '%s\n' private-local
}

# shellcheck source=lib/exit_codes.sh
source "./lib/exit_codes.sh"
# shellcheck source=lib/report.sh
source "./lib/report.sh"
: >"$REPORT_FILE"
report_finalize "$EXIT_AUR_DISCOVERY_FAILED"

grep -Fq 'Official updates' "$REPORT_FILE"
grep -Fq 'Installed: 3' "$REPORT_FILE"
grep -Fq 'Result   : INSTALLED' "$REPORT_FILE"
grep -Fq 'AUR updates' "$REPORT_FILE"
grep -Fq 'Stable approved        : 2' "$REPORT_FILE"
grep -Fq 'Unstable skipped       : 2' "$REPORT_FILE"
grep -Fq 'Unknown foreign        : 1' "$REPORT_FILE"
grep -Fq 'Result                 : DEFERRED_HELPER_INCOMPATIBLE' "$REPORT_FILE"
grep -Fq 'Failed                 : 0' "$REPORT_FILE"
grep -Fq 'Deferred               : Official update succeeded' "$REPORT_FILE"
grep -Fq 'Helper recheck required: yes' "$REPORT_FILE"
grep -Fq 'Helper post-update     : INCOMPATIBLE' "$REPORT_FILE"
grep -Fq 'Code de sortie           : 31 (AUR_DISCOVERY_FAILED)' "$REPORT_FILE"

printf 'Tous les tests du rapport AUR partiel ont réussi.\n'
