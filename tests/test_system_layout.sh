#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Eeuo pipefail

TARGET="./bin/smart-update"

if [[ ! -r "$TARGET" ]]; then
    printf 'Erreur : programme principal introuvable.\n' >&2
    exit 1
fi

assert_contains() {
    local expected="${1:-}"

    if ! grep -Fq -- "$expected" "$TARGET"; then
        printf 'Erreur : élément de layout attendu absent : %s\n' "$expected" >&2
        exit 1
    fi
}

# Le mode développement doit rester pris en charge.
assert_contains 'if [[ -r "${SCRIPT_DIR}/../lib/config.sh" ]]; then'
assert_contains '    LIB_DIR="${PROJECT_ROOT}/lib"'
assert_contains '    CONFIG_DIR="${PROJECT_ROOT}/config"'
assert_contains '    TOOLS_DIR="${PROJECT_ROOT}/tools"'

# Le layout système v1.0 doit être explicite et indépendant du dépôt Git.
assert_contains '    PROJECT_ROOT="/usr/lib/smart-update"'
assert_contains '    LIB_DIR="/usr/lib/smart-update"'
assert_contains '    CONFIG_DIR="/etc/smart-update"'
assert_contains '    TOOLS_DIR="/usr/lib/smart-update"'

# Les composants doivent être résolus depuis les répertoires abstraits.
assert_contains 'readonly CONFIG_FILE="${CONFIG_DIR}/smart-update.conf"'
assert_contains 'readonly CONFIG_MODULE="${LIB_DIR}/config.sh"'
assert_contains 'readonly LOGGER_MODULE="${LIB_DIR}/logger.sh"'
assert_contains 'readonly DECISION_MODULE="${LIB_DIR}/decision.sh"'
assert_contains 'readonly SYSTEM_CHECKS_MODULE="${LIB_DIR}/system_checks.sh"'
assert_contains 'readonly REPORT_MODULE="${LIB_DIR}/report.sh"'
assert_contains 'readonly ENGINE_MODULE="${LIB_DIR}/engine.sh"'
assert_contains 'readonly ARCH_NEWS_CONTEXT_MODULE="${LIB_DIR}/arch_news_context.sh"'
assert_contains 'readonly PACKAGE_REMOVALS_MODULE="${LIB_DIR}/package_removals.sh"'
assert_contains 'readonly PACKAGE_REPLACEMENTS_MODULE="${LIB_DIR}/package_replacements.sh"'

# Le helper natif installé doit vivre directement dans /usr/lib/smart-update.
assert_contains '    readonly PACKAGE_REMOVALS_HELPER="${TOOLS_DIR}/package-removals-helper"'

# Les données mutables ne doivent jamais être placées sous /usr.
assert_contains 'readonly STATE_DIR="/var/lib/smart-update"'
assert_contains 'readonly LOCK_FILE="/run/lock/smart-update.lock"'

printf 'Tous les tests du layout système ont réussi.\n'
