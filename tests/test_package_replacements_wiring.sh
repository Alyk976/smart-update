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

assert_exact_line \
    'readonly PACKAGE_REPLACEMENTS_MODULE="${PROJECT_ROOT}/lib/package_replacements.sh"'

assert_exact_line \
    'source "${PROJECT_ROOT}/lib/package_replacements.sh"'

assert_exact_line 'prepare_package_replacements_context() {'

assert_exact_line \
    '    if ! package_replacements_collect "$PACKAGE_REMOVALS_HELPER"; then'

prepare_replacements_line=$(line_number "    prepare_package_replacements_context")
engine_load_line=$(line_number "    engine_load_policies")
engine_run_line=$(line_number "    engine_run_policies")

if ((prepare_replacements_line >= engine_load_line)); then
    printf "Erreur : le contexte des remplacements doit être préparé avant le chargement des politiques.\n" >&2
    exit 1
fi

if ((engine_load_line >= engine_run_line)); then
    printf "Erreur : ordre du moteur de politiques invalide.\n" >&2
    exit 1
fi

printf "Tous les tests du câblage des remplacements ont réussi.\n"
