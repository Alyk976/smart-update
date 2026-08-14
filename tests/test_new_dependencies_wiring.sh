#!/usr/bin/env bash

set -Eeuo pipefail

TARGET="./bin/smart-update"

if [[ ! -r "$TARGET" ]]; then
    printf "Erreur : programme principal introuvable.\n" >&2
    exit 1
fi

assert_exact_line() {
    local expected_line="${1:-}"
    local count

    count=$(
        grep -F -c -x -- "$expected_line" "$TARGET" \
            || true
    )

    if ((count != 1)); then
        printf 'Erreur : ligne attendue %q trouvée %d fois.\n' \
            "$expected_line" \
            "$count" >&2
        exit 1
    fi
}

line_number() {
    local expected_line="${1:-}"

    grep \
        -F \
        -n \
        -m 1 \
        -x \
        -- "$expected_line" \
        "$TARGET" \
        | cut -d: -f1
}

assert_exact_line 'readonly PACKAGE_ADDITIONS_MODULE="${LIB_DIR}/package_additions.sh"'
assert_exact_line 'source "$PACKAGE_ADDITIONS_MODULE"'
assert_exact_line 'prepare_transaction_context() {'
assert_exact_line '    if ! package_additions_collect "$PACKAGE_REMOVALS_HELPER"; then'
assert_exact_line '    prepare_transaction_context'
assert_exact_line '    engine_load_policies'
assert_exact_line '    engine_run_policies'
assert_exact_line '    simulate_transaction'

prepare_line=$(line_number "    prepare_transaction_context")
engine_load_line=$(line_number "    engine_load_policies")
engine_run_line=$(line_number "    engine_run_policies")
simulate_line=$(line_number "    simulate_transaction")

if ((prepare_line >= engine_load_line)); then
    printf "Erreur : le contexte de transaction doit être préparé avant le chargement des politiques.\n" >&2
    exit 1
fi

if ((engine_load_line >= engine_run_line)); then
    printf "Erreur : ordre du moteur de politiques invalide.\n" >&2
    exit 1
fi

if ((engine_run_line >= simulate_line)); then
    printf "Erreur : la journalisation de la simulation doit suivre l’exécution des politiques.\n" >&2
    exit 1
fi

if grep -Fq 'pacman -Syu --print' "$TARGET"; then
    printf "Erreur : la détection des nouvelles dépendances dépend encore de pacman --print.\n" >&2
    exit 1
fi

if grep -Fq 'decision_add \' <(
    sed -n '/^simulate_transaction() {/,/^}/p' "$TARGET"
); then
    printf "Erreur : simulate_transaction contient encore une décision directe.\n" >&2
    exit 1
fi

printf "Tous les tests du câblage des nouvelles dépendances ont réussi.\n"
