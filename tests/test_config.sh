#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck source=lib/config.sh
source "./lib/config.sh"

VALID_CONFIG="$TEST_DIR/valid.conf"

cat >"$VALID_CONFIG" <<'CONF'
MODE="audit"
ALLOW_AUR="no"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF

config_load "$VALID_CONFIG"

[[ "$MODE" == "audit" ]]
[[ "$ALLOW_AUR" == "no" ]]
[[ "$MAX_UPDATE_COUNT" == "100" ]]
[[ "$CHECK_ARCH_NEWS" == "yes" ]]
[[ "$ARCH_NEWS_LIMIT" == "10" ]]

if config_load "$TEST_DIR/missing.conf" 2>/dev/null; then
    printf 'Erreur : un fichier absent a été accepté.\n' >&2
    exit 1
fi

INVALID_MODE_CONFIG="$TEST_DIR/invalid-mode.conf"

cat >"$INVALID_MODE_CONFIG" <<'CONF'
MODE="invalid"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF

if config_load "$INVALID_MODE_CONFIG" 2>/dev/null; then
    printf 'Erreur : un MODE invalide a été accepté.\n' >&2
    exit 1
fi

ZERO_COUNT_CONFIG="$TEST_DIR/zero-count.conf"

cat >"$ZERO_COUNT_CONFIG" <<'CONF'
MODE="audit"
MAX_UPDATE_COUNT=0
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF

if config_load "$ZERO_COUNT_CONFIG" 2>/dev/null; then
    printf 'Erreur : MAX_UPDATE_COUNT=0 a été accepté.\n' >&2
    exit 1
fi

INVALID_COUNT_CONFIG="$TEST_DIR/invalid-count.conf"

cat >"$INVALID_COUNT_CONFIG" <<'CONF'
MODE="audit"
MAX_UPDATE_COUNT=abc
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF

if config_load "$INVALID_COUNT_CONFIG" 2>/dev/null; then
    printf 'Erreur : MAX_UPDATE_COUNT=abc a été accepté.\n' >&2
    exit 1
fi

INVALID_ARCH_NEWS_CONFIG="$TEST_DIR/invalid-arch-news.conf"

cat >"$INVALID_ARCH_NEWS_CONFIG" <<'CONF'
MODE="audit"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="maybe"
ARCH_NEWS_LIMIT=10
CONF

if config_load "$INVALID_ARCH_NEWS_CONFIG" 2>/dev/null; then
    printf 'Erreur : CHECK_ARCH_NEWS=maybe a été accepté.\n' >&2
    exit 1
fi

ZERO_ARCH_NEWS_LIMIT_CONFIG="$TEST_DIR/zero-arch-news-limit.conf"

cat >"$ZERO_ARCH_NEWS_LIMIT_CONFIG" <<'CONF'
MODE="audit"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=0
CONF

if config_load "$ZERO_ARCH_NEWS_LIMIT_CONFIG" 2>/dev/null; then
    printf 'Erreur : ARCH_NEWS_LIMIT=0 a été accepté.\n' >&2
    exit 1
fi

INVALID_ARCH_NEWS_LIMIT_CONFIG="$TEST_DIR/invalid-arch-news-limit.conf"

cat >"$INVALID_ARCH_NEWS_LIMIT_CONFIG" <<'CONF'
MODE="audit"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=abc
CONF

if config_load "$INVALID_ARCH_NEWS_LIMIT_CONFIG" 2>/dev/null; then
    printf 'Erreur : ARCH_NEWS_LIMIT=abc a été accepté.\n' >&2
    exit 1
fi

printf 'Tous les tests du module config ont réussi.\n'
