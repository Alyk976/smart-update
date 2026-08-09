#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Eeuo pipefail

TARGET="./bin/smart-update"

[[ -r "$TARGET" ]] || {
    printf 'Erreur : programme principal introuvable.\n' >&2
    exit 1
}

assert_contains() {
    local expected="${1:?}"

    grep -Fq -- "$expected" "$TARGET" || {
        printf 'Erreur : câblage de finalisation absent : %s\n' "$expected" >&2
        exit 1
    }
}

line_number() {
    local expected="${1:?}"

    grep -F -n -m 1 -- "$expected" "$TARGET" | cut -d: -f1
}

assert_contains 'finalize_report_on_exit() {'
assert_contains 'trap finalize_report_on_exit EXIT'
assert_contains 'report_finalize "$exit_code" || true'
assert_contains '    create_report'
assert_contains '    check_network'
assert_contains '    check_pacman_lock'
assert_contains '    check_root_space'

create_line=$(line_number '    create_report')
trap_line=$(line_number '    trap finalize_report_on_exit EXIT')
network_line=$(line_number '    check_network')
lock_line=$(line_number '    check_pacman_lock')
space_line=$(line_number '    check_root_space')

if ! ((create_line < trap_line \
    && trap_line < network_line \
    && network_line < lock_line \
    && lock_line < space_line)); then
    printf 'Erreur : ordre de protection des rapports invalide.\n' >&2
    exit 1
fi

printf 'Tous les tests de finalisation runtime des rapports ont réussi.\n'
