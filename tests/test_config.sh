#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck source=lib/config.sh
source "./lib/config.sh"

# La configuration distribuée autorise normalement les mises à jour
# critiques stables, tout en conservant un verdict WARNING, mais laisse
# l'automatisation AUR désactivée jusqu'à la configuration d'une identité.
config_load "./config/smart-update.conf"
[[ "$ALLOW_CRITICAL_UPDATES" == "yes" ]]
[[ "$ENABLE_AUR_UPDATES" == "no" ]]

VALID_CONFIG="$TEST_DIR/valid.conf"

cat >"$VALID_CONFIG" <<'CONF'
MODE="audit"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
ALLOW_CRITICAL_UPDATES="no"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF

config_load "$VALID_CONFIG"

[[ "$MODE" == "audit" ]]
[[ "$ENABLE_AUR_UPDATES" == "yes" ]]
[[ "$AUR_HELPER" == "yay" ]]
[[ "$AUR_USER" == "auto" ]]
[[ "$ALLOW_CRITICAL_UPDATES" == "no" ]]
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
ALLOW_CRITICAL_UPDATES="no"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
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
ALLOW_CRITICAL_UPDATES="no"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
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
ALLOW_CRITICAL_UPDATES="no"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
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
ALLOW_CRITICAL_UPDATES="no"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
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
ALLOW_CRITICAL_UPDATES="no"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
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
ALLOW_CRITICAL_UPDATES="no"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=abc
CONF

if config_load "$INVALID_ARCH_NEWS_LIMIT_CONFIG" 2>/dev/null; then
    printf 'Erreur : ARCH_NEWS_LIMIT=abc a été accepté.\n' >&2
    exit 1
fi

VALID_CRITICAL_YES_CONFIG="$TEST_DIR/valid-critical-yes.conf"
cat >"$VALID_CRITICAL_YES_CONFIG" <<'CONF'
MODE="audit"
ALLOW_CRITICAL_UPDATES="yes"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF
config_load "$VALID_CRITICAL_YES_CONFIG"
[[ "$ALLOW_CRITICAL_UPDATES" == "yes" ]]

INVALID_CRITICAL_CONFIG="$TEST_DIR/invalid-critical.conf"
cat >"$INVALID_CRITICAL_CONFIG" <<'CONF'
MODE="audit"
ALLOW_CRITICAL_UPDATES="maybe"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF
if config_load "$INVALID_CRITICAL_CONFIG" 2>/dev/null; then
    printf 'Erreur : ALLOW_CRITICAL_UPDATES=maybe a été accepté.\n' >&2
    exit 1
fi

MISSING_CRITICAL_CONFIG="$TEST_DIR/missing-critical.conf"
cat >"$MISSING_CRITICAL_CONFIG" <<'CONF'
MODE="audit"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF
unset ALLOW_CRITICAL_UPDATES
if config_load "$MISSING_CRITICAL_CONFIG" 2>/dev/null; then
    printf 'Erreur : ALLOW_CRITICAL_UPDATES absente a été acceptée.\n' >&2
    exit 1
fi

for invalid_aur_config in \
    'ENABLE_AUR_UPDATES="maybe"|AUR_HELPER="yay"|AUR_USER="auto"' \
    'ENABLE_AUR_UPDATES="yes"|AUR_HELPER="paru"|AUR_USER="auto"' \
    'ENABLE_AUR_UPDATES="yes"|AUR_HELPER="yay"|AUR_USER="root"' \
    'ENABLE_AUR_UPDATES="yes"|AUR_HELPER="yay"|AUR_USER="invalid user"'; do
    IFS='|' read -r aur_enabled aur_helper aur_user <<<"$invalid_aur_config"
    cat >"$TEST_DIR/invalid-aur.conf" <<CONF
MODE="audit"
ALLOW_CRITICAL_UPDATES="yes"
${aur_enabled}
${aur_helper}
${aur_user}
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF
    if config_load "$TEST_DIR/invalid-aur.conf" 2>/dev/null; then
        printf 'Erreur : configuration AUR invalide acceptée.\n' >&2
        exit 1
    fi
done

cat >"$TEST_DIR/missing-aur.conf" <<'CONF'
MODE="audit"
ALLOW_CRITICAL_UPDATES="yes"
MAX_UPDATE_COUNT=100
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
CONF
if config_load "$TEST_DIR/missing-aur.conf" 2>/dev/null; then
    printf 'Erreur : paramètres AUR absents acceptés.\n' >&2
    exit 1
fi

printf 'Tous les tests du module config ont réussi.\n'
