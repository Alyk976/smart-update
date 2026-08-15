#!/usr/bin/env bash
# shellcheck disable=SC2034

set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin"

cat >"$TEST_DIR/bin/pacman" <<'MOCK'
#!/usr/bin/env bash

if [[ "${1:-}" == "-Qqm" ]]; then
    if [[ -n "${MOCK_FOREIGN_PACKAGES:-}" ]]; then
        printf '%s\n' "$MOCK_FOREIGN_PACKAGES"
    fi
    exit 0
fi

exit 1
MOCK

chmod +x "$TEST_DIR/bin/pacman"
export PATH="$TEST_DIR/bin:$PATH"

LOG_FILE="$TEST_DIR/smart-update.log"
BLOCKED_LOG="$TEST_DIR/blocked.log"
touch "$LOG_FILE" "$BLOCKED_LOG"

# shellcheck source=lib/logger.sh
source "$PROJECT_ROOT/lib/logger.sh"

# shellcheck source=lib/decision.sh
source "$PROJECT_ROOT/lib/decision.sh"

# shellcheck source=lib/engine.sh
source "$PROJECT_ROOT/lib/engine.sh"
# shellcheck source=lib/stability.sh
source "$PROJECT_ROOT/lib/stability.sh"

reset_context() {
    UPDATE_PACKAGES=(nano)
    MAX_UPDATE_COUNT=500
    ALLOW_CRITICAL_UPDATES="no"

    PACKAGE_CANDIDATES_ERROR=""
    PACKAGE_CANDIDATE_REPOS=(core)
    PACKAGE_CANDIDATE_NAMES=(nano)
    PACKAGE_CANDIDATE_VERSIONS=(8.0-1)

    MOCK_FOREIGN_PACKAGES=""
    export MOCK_FOREIGN_PACKAGES

    ARCH_NEWS_CONTEXT_STATUS="UP_TO_DATE"
    ARCH_NEWS_CONTEXT_ERROR=""
    ARCH_NEWS_NEW_INDEXES=()
    ARCH_NEWS_TITLES=()
    ARCH_NEWS_DATES=()
    ARCH_NEWS_LINKS=()
    ARCH_NEWS_DESCRIPTIONS=()

    PACKAGE_REMOVALS=()
    PACKAGE_REMOVALS_ERROR=""
    ALLOW_REMOVALS="no"

    PACKAGE_REPLACEMENTS=()
    PACKAGE_REPLACEMENTS_ERROR=""
    ALLOW_REPLACEMENTS="no"

    ALLOW_OVERWRITE="no"

    NEW_PACKAGES=()
    NEW_PACKAGES_ERROR=""
    ALLOW_NEW_DEPENDENCIES="no"

    : >"$LOG_FILE"
    : >"$BLOCKED_LOG"

    decision_reset
    engine_load_policies
}

# Scénario 1 : tous les contrôles sont sûrs -> ALLOW.
reset_context
engine_run_policies >/dev/null

[[ "$DECISION_FINAL" == "ALLOW" ]]
decision_allows_installation

# Scénario 2 : une nouvelle dépendance explicitement autorisée -> WARNING.
reset_context
NEW_PACKAGES=(gexiv2-common)
ALLOW_NEW_DEPENDENCIES="yes"

engine_run_policies >/dev/null

[[ "$DECISION_FINAL" == "WARNING" ]]
decision_allows_installation

# Scénario 3 : un avertissement et un risque critique -> BLOCK prioritaire.
reset_context
UPDATE_PACKAGES=(linux nano)
MOCK_FOREIGN_PACKAGES="aur-test-package"
export MOCK_FOREIGN_PACKAGES
NEW_PACKAGES=(gexiv2-common)
ALLOW_NEW_DEPENDENCIES="yes"

engine_run_policies >/dev/null

[[ "$DECISION_FINAL" == "BLOCK" ]]

if decision_allows_installation; then
    printf "Erreur : la décision finale BLOCK autorise l’installation.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]

grep -Fq "Policy critical_updates: Mises à jour critiques bloquées par la configuration :" "$LOG_FILE"
grep -Fq "Policy foreign_packages: 1 paquet(s) étranger(s)/AUR détecté(s)." "$LOG_FILE"
grep -Fq "Policy new_dependencies: 1 nouveau(x) paquet(s) ou nouvelle(s) dépendance(s) détecté(s)." "$LOG_FILE"

# Scénario 4 : autoriser les critiques ne contourne jamais la stabilité.
reset_context
UPDATE_PACKAGES=(linux)
ALLOW_CRITICAL_UPDATES="yes"
PACKAGE_CANDIDATE_REPOS=(core-testing)
PACKAGE_CANDIDATE_NAMES=(linux)
PACKAGE_CANDIDATE_VERSIONS=(6.13.0-rc2)

engine_run_policies >/dev/null

[[ "$DECISION_FINAL" == "BLOCK" ]]
grep -Fq "Policy stable_updates: Candidats de mise à jour non stables ou non officiels détectés :" "$LOG_FILE"
grep -Fq "Policy critical_updates: Mises à jour critiques stables autorisées avec avertissement :" "$LOG_FILE"

if decision_allows_installation; then
    printf 'Erreur : un paquet critique instable franchit le Decision Gate.\n' >&2
    exit 1
fi

printf "Tous les tests d’intégration du moteur de politiques ont réussi.\n"
