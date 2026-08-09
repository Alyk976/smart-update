#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Eeuo pipefail

TARGET="./bin/smart-update"

if [[ ! -r "$TARGET" ]]; then
    printf "Erreur : programme principal introuvable.\n" >&2
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

assert_exact_line \
    'readonly PACKAGE_REMOVALS_MODULE="${LIB_DIR}/package_removals.sh"'

assert_exact_line \
    'source "$PACKAGE_REMOVALS_MODULE"'

assert_exact_line \
    'if [[ -x "${TOOLS_DIR}/package-removals-helper/package-removals-helper" ]]; then'

assert_exact_line \
    '    readonly PACKAGE_REMOVALS_HELPER="${TOOLS_DIR}/package-removals-helper/package-removals-helper"'

assert_exact_line \
    '    readonly PACKAGE_REMOVALS_HELPER="${TOOLS_DIR}/package-removals-helper"'

assert_exact_line 'prepare_package_removals_context() {'
assert_exact_line '    prepare_package_removals_context'
assert_exact_line '    engine_load_policies'
assert_exact_line '    engine_run_policies'

prepare_position=$(line_number '    prepare_package_removals_context')
load_position=$(line_number '    engine_load_policies')
run_position=$(line_number '    engine_run_policies')

if ((prepare_position >= load_position || load_position >= run_position)); then
    printf "Erreur : ordre du workflow Package Removals invalide.\n" >&2
    exit 1
fi

printf "Tous les tests du câblage Package Removals ont réussi.\n"
