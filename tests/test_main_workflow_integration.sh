#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016

set -Eeuo pipefail

TARGET="./bin/smart-update"

if [[ ! -r "$TARGET" ]]; then
    printf 'Erreur : programme principal introuvable.\n' >&2
    exit 1
fi

assert_exact_line() {
    local expected_line="${1:-}"
    local count

    count=$(grep -F -c -x -- "$expected_line" "$TARGET" || true)

    if ((count != 1)); then
        printf 'Erreur : ligne attendue %q trouvée %d fois.\n' \
            "$expected_line" "$count" >&2
        exit 1
    fi
}

line_number() {
    local expected_line="${1:-}"

    grep -F -n -m 1 -x -- "$expected_line" "$TARGET" | cut -d: -f1
}

# Le workflow principal doit préparer tous les contextes avant les policies.
assert_exact_line '    load_updates'
assert_exact_line '    prepare_arch_news_context'
assert_exact_line '    prepare_package_removals_context'
assert_exact_line '    prepare_package_replacements_context'
assert_exact_line '    prepare_transaction_context'
assert_exact_line '    prepare_package_candidates_context'
assert_exact_line '    engine_load_policies'
assert_exact_line '    engine_run_policies'
assert_exact_line '    simulate_transaction'
assert_exact_line '    persist_arch_news_context'
assert_exact_line '    enforce_final_decision'
assert_exact_line '    install_updates'
assert_exact_line '    report_finalize "$EXIT_OK"'

load_line=$(line_number '    load_updates')
arch_news_line=$(line_number '    prepare_arch_news_context')
removals_line=$(line_number '    prepare_package_removals_context')
replacements_line=$(line_number '    prepare_package_replacements_context')
transaction_line=$(line_number '    prepare_transaction_context')
candidates_line=$(line_number '    prepare_package_candidates_context')
engine_load_line=$(line_number '    engine_load_policies')
engine_run_line=$(line_number '    engine_run_policies')
simulation_line=$(line_number '    simulate_transaction')
persist_line=$(line_number '    persist_arch_news_context')
gate_line=$(line_number '    enforce_final_decision')
install_line=$(line_number '    install_updates')
report_line=$(line_number '    report_finalize "$EXIT_OK"')

previous=0
for current in \
    "$load_line" \
    "$arch_news_line" \
    "$removals_line" \
    "$replacements_line" \
    "$transaction_line" \
    "$candidates_line" \
    "$engine_load_line" \
    "$engine_run_line" \
    "$simulation_line" \
    "$persist_line" \
    "$gate_line" \
    "$install_line" \
    "$report_line"; do

    if ((current <= previous)); then
        printf 'Erreur : ordre du workflow principal invalide.\n' >&2
        exit 1
    fi

    previous=$current
done

# Invariant de sécurité majeur : aucune installation ne doit précéder
# le contrôle de la décision finale.
if ((gate_line >= install_line)); then
    printf 'Erreur : install_updates est appelé avant le Decision Gate.\n' >&2
    exit 1
fi

# Vérifie aussi le comportement du gate indépendamment de Pacman.
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

LOG_FILE="$TEST_DIR/smart-update.log"
BLOCKED_LOG="$TEST_DIR/blocked.log"
touch "$LOG_FILE" "$BLOCKED_LOG"

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT

# shellcheck source=lib/logger.sh
source "$PROJECT_ROOT/lib/logger.sh"
# shellcheck source=lib/decision.sh
source "$PROJECT_ROOT/lib/decision.sh"

# Reproduction minimale du gate : BLOCK doit refuser l'installation.
decision_reset
decision_add "BLOCK" "Risque d'intégration simulé."

if decision_allows_installation; then
    printf 'Erreur : BLOCK autorise le passage vers install_updates.\n' >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]
[[ "$DECISION_FINAL" == "BLOCK" ]]

# WARNING reste autorisable par le gate ; le mode audit empêchera ensuite
# toute installation réelle dans le programme principal.
decision_reset
decision_add "WARNING" "Avertissement d'intégration simulé."
decision_allows_installation
[[ "$DECISION_FINAL" == "WARNING" ]]

# ALLOW doit également franchir le gate.
decision_reset
decision_allows_installation
[[ "$DECISION_FINAL" == "ALLOW" ]]

# Le mode audit retourne avant l'unique invocation de Pacman dans
# install_updates, quelle que soit la décision autorisable.
audit_guard_line=$(grep -n -m 1 'if \[\[ "$MODE" == "audit" \]\]' "$TARGET" | cut -d: -f1)
pacman_install_line=$(grep -n -m 1 'pacman -Syu --needed' "$TARGET" | cut -d: -f1)
if ((audit_guard_line >= pacman_install_line)); then
    printf 'Erreur : le mode audit peut atteindre Pacman.\n' >&2
    exit 1
fi

printf "Tous les tests d’intégration du workflow principal ont réussi.\n"
