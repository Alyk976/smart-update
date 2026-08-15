#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck source=lib/package_candidates.sh
source "./lib/package_candidates.sh"

make_helper() {
    local name="${1:?}" body="${2:?}"
    printf '#!/usr/bin/env bash\n[[ "${1:-}" == "--additions-meta" ]]\n%s\n' \
        "$body" >"$TEST_DIR/$name"
    chmod +x "$TEST_DIR/$name"
}

make_helper valid "printf '%s\\n' 'core|linux|6.12.1-1' 'extra|firefox|133.0-1'"
make_helper malformed "printf '%s\\n' 'core|linux'"
make_helper empty "printf '%s\\n' 'core||1.0-1'"
make_helper bad_repo "printf '%s\\n' 'bad repo|linux|1.0-1'"
make_helper bad_package "printf '%s\\n' 'core|bad package|1.0-1'"
make_helper extra_field "printf '%s\\n' 'core|linux|1.0-1|extra'"
make_helper failing "printf '%s\\n' 'libalpm failed' >&2; exit 9"

package_candidates_collect "$TEST_DIR/valid"
[[ -z "$PACKAGE_CANDIDATES_ERROR" ]]
((${#PACKAGE_CANDIDATE_NAMES[@]} == 2))
[[ "${PACKAGE_CANDIDATE_REPOS[0]}" == "core" ]]
[[ "${PACKAGE_CANDIDATE_NAMES[1]}" == "firefox" ]]
[[ "${PACKAGE_CANDIDATE_VERSIONS[1]}" == "133.0-1" ]]

for invalid_helper in malformed empty bad_repo bad_package extra_field failing; do
    if package_candidates_collect "$TEST_DIR/$invalid_helper"; then
        printf 'Erreur : sortie invalide acceptée (%s).\n' "$invalid_helper" >&2
        exit 1
    fi
    ((${#PACKAGE_CANDIDATE_REPOS[@]} == 0))
    ((${#PACKAGE_CANDIDATE_NAMES[@]} == 0))
    ((${#PACKAGE_CANDIDATE_VERSIONS[@]} == 0))
    [[ -n "$PACKAGE_CANDIDATES_ERROR" ]]
done

printf 'Tous les tests du collecteur de candidats ont réussi.\n'
