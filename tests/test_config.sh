#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck source=lib/config.sh
source "./lib/config.sh"

VALID_CONFIG="$TEST_DIR/valid.conf"

cat > "$VALID_CONFIG" <<'CONF'
MODE="audit"
ALLOW_AUR="no"
MAX_UPDATE_COUNT=100
CONF

config_load "$VALID_CONFIG"

[[ "$MODE" == "audit" ]]
[[ "$ALLOW_AUR" == "no" ]]
[[ "$MAX_UPDATE_COUNT" == "100" ]]

if config_load "$TEST_DIR/missing.conf" 2>/dev/null; then
    printf 'Erreur : un fichier absent a été accepté.\n' >&2
    exit 1
fi

INVALID_MODE_CONFIG="$TEST_DIR/invalid-mode.conf"

cat > "$INVALID_MODE_CONFIG" <<'CONF'
MODE="invalid"
MAX_UPDATE_COUNT=100
CONF

if config_load "$INVALID_MODE_CONFIG" 2>/dev/null; then
    printf 'Erreur : un MODE invalide a été accepté.\n' >&2
    exit 1
fi

ZERO_COUNT_CONFIG="$TEST_DIR/zero-count.conf"

cat > "$ZERO_COUNT_CONFIG" <<'CONF'
MODE="audit"
MAX_UPDATE_COUNT=0
CONF

if config_load "$ZERO_COUNT_CONFIG" 2>/dev/null; then
    printf 'Erreur : MAX_UPDATE_COUNT=0 a été accepté.\n' >&2
    exit 1
fi

INVALID_COUNT_CONFIG="$TEST_DIR/invalid-count.conf"

cat > "$INVALID_COUNT_CONFIG" <<'CONF'
MODE="audit"
MAX_UPDATE_COUNT=abc
CONF

if config_load "$INVALID_COUNT_CONFIG" 2>/dev/null; then
    printf 'Erreur : MAX_UPDATE_COUNT=abc a été accepté.\n' >&2
    exit 1
fi

printf 'Tous les tests du module config ont réussi.\n'
