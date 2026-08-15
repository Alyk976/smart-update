#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
MOCK_OUTPUT=""
MOCK_STATUS=0

helper_mock() {
    [[ "${1:-}" == "--questions" ]]
    printf '%s\n' "$MOCK_OUTPUT"
    return "$MOCK_STATUS"
}

# shellcheck source=lib/transaction_questions.sh
source "./lib/transaction_questions.sh"

MOCK_OUTPUT=""
transaction_questions_collect helper_mock
[[ "$OFFICIAL_EXECUTION_CAPABILITY" == "AUTOMATIC" ]]

MOCK_OUTPUT='CONFLICT_PKG|qemu-common|11.1.0-1|qemu-block-gluster|11.0.3-1'
transaction_questions_collect helper_mock
[[ "$OFFICIAL_EXECUTION_CAPABILITY" == "MANUAL_REQUIRED" ]]
[[ "${TRANSACTION_QUESTIONS[0]}" == *qemu-block-gluster* ]]

for type in REPLACE_PKG SELECT_PROVIDER INSTALL_IGNOREPKG REMOVE_PKGS \
    CORRUPTED_PKG IMPORT_KEY UNKNOWN; do
    MOCK_OUTPUT="${type}||||"
    transaction_questions_collect helper_mock
    [[ "$OFFICIAL_EXECUTION_CAPABILITY" == "MANUAL_REQUIRED" ]]
done

MOCK_OUTPUT='CONFLICT_PKG|pkg|1|other'
if transaction_questions_collect helper_mock; then
    printf 'Erreur : question mal formée acceptée.\n' >&2
    exit 1
fi
[[ "$OFFICIAL_EXECUTION_CAPABILITY" == "MANUAL_REQUIRED" ]]

MOCK_OUTPUT=""
MOCK_STATUS=7
if transaction_questions_collect helper_mock; then
    printf 'Erreur : échec helper accepté.\n' >&2
    exit 1
fi
[[ "$OFFICIAL_EXECUTION_CAPABILITY" == "MANUAL_REQUIRED" ]]
MOCK_STATUS=0

# Une nouvelle dépendance sans question reste automatique.
MOCK_OUTPUT=""
PACKAGE_ADDITIONS=(gexiv2 gexiv2-common)
transaction_questions_collect helper_mock
[[ "$OFFICIAL_EXECUTION_CAPABILITY" == "AUTOMATIC" ]]

UPDATE_LINES=('gexiv2 0.16.1-1 -> 0.16.2-2')
PACKAGE_REMOVALS=()
PACKAGE_REPLACEMENTS=()
PACKAGE_CANDIDATE_REPOS=(extra extra)
PACKAGE_CANDIDATE_NAMES=(gexiv2 gexiv2-common)
PACKAGE_CANDIDATE_VERSIONS=(0.16.2-2 0.16.2-2)
snapshot_before=$(transaction_snapshot)
PACKAGE_CANDIDATE_VERSIONS[1]=0.16.2-3
snapshot_after=$(transaction_snapshot)
[[ "$snapshot_before" != "$snapshot_after" ]]

printf 'Tous les tests de capacité transactionnelle ont réussi.\n'
