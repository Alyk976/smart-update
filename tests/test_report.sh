#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

REPORT_DIR="$TEST_DIR"
REPORT_FILE="$TEST_DIR/report-test.txt"
REPORT_START_EPOCH=$(($(date +%s) - 4))

DECISION_FINAL="BLOCK"
DECISION_TYPES=("WARNING" "BLOCK")
DECISION_REASONS=(
    "Mises à jour critiques détectées :"
    "Nouveaux paquets ou nouvelles dépendances détectés :"
)

UPDATE_PACKAGES=(
    "bash"
    "linux"
    "openssl"
)

CRITICAL_UPDATES=(
    "linux"
    "openssl"
)

NEW_PACKAGES=(
    "cmark-gfm"
)

logger_info() {
    :
}

pacman() {
    case "${1:-}" in
        -Qmq)
            printf '%s\n' \
                "google-chrome" \
                "visual-studio-code-bin"
            ;;
        *)
            return 1
            ;;
    esac
}

# shellcheck source=lib/report.sh
source "./lib/report.sh"

: >"$REPORT_FILE"

report_finalize

grep -Fq "Décision finale" "$REPORT_FILE"
grep -Fq "BLOCK" "$REPORT_FILE"
grep -Fq "[WARNING] Mises à jour critiques détectées :" "$REPORT_FILE"
grep -Fq "    - linux" "$REPORT_FILE"
grep -Fq "    - openssl" "$REPORT_FILE"
grep -Fq "[BLOCK] Nouveaux paquets ou nouvelles dépendances détectés :" "$REPORT_FILE"
grep -Fq "    - cmark-gfm" "$REPORT_FILE"
grep -Fq "Paquets à mettre à jour : 3" "$REPORT_FILE"
grep -Fq "Paquets critiques       : 2" "$REPORT_FILE"
grep -Fq "Nouvelles dépendances   : 1" "$REPORT_FILE"
grep -Fq "Paquets étrangers/AUR   : 2" "$REPORT_FILE"
grep -Fq "Verdict                  : BLOCK" "$REPORT_FILE"
grep -Eq 'Durée[[:space:]]+: 00:00:0[4-9]' "$REPORT_FILE"
grep -Fq "Fin du rapport :" "$REPORT_FILE"

printf 'Tous les tests du module report ont réussi.\n'
