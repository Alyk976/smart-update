#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck source=lib/package_replacements.sh
source "./lib/package_replacements.sh"

cat >"$TEST_DIR/empty-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--replacements" ]] || exit 9
exit 0
HELPER

cat >"$TEST_DIR/replacements-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--replacements" ]] || exit 9
printf '%s\n' \
    'atk|at-spi2-core' \
    'at-spi2-atk|at-spi2-core' \
    'atk|at-spi2-core'
HELPER

cat >"$TEST_DIR/invalid-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--replacements" ]] || exit 9
printf '%s\n' 'invalid replacement'
HELPER

cat >"$TEST_DIR/failing-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--replacements" ]] || exit 9
printf '%s\n' 'transaction preparation failed' >&2
exit 7
HELPER

chmod +x \
    "$TEST_DIR/empty-helper" \
    "$TEST_DIR/replacements-helper" \
    "$TEST_DIR/invalid-helper" \
    "$TEST_DIR/failing-helper"

package_replacements_collect "$TEST_DIR/empty-helper"

[[ -z "$PACKAGE_REPLACEMENTS_ERROR" ]]
((${#PACKAGE_REPLACEMENTS[@]} == 0))

package_replacements_collect "$TEST_DIR/replacements-helper"

[[ -z "$PACKAGE_REPLACEMENTS_ERROR" ]]
((${#PACKAGE_REPLACEMENTS[@]} == 2))
[[ "${PACKAGE_REPLACEMENTS[0]}" == "atk|at-spi2-core" ]]
[[ "${PACKAGE_REPLACEMENTS[1]}" == "at-spi2-atk|at-spi2-core" ]]

if package_replacements_collect "$TEST_DIR/invalid-helper"; then
    printf "Erreur : une sortie de remplacement invalide a été acceptée.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 2 ]]
((${#PACKAGE_REPLACEMENTS[@]} == 0))
[[ "$PACKAGE_REPLACEMENTS_ERROR" == \
    "Remplacement invalide renvoyé par le collecteur : invalid replacement." ]]

if package_replacements_collect "$TEST_DIR/failing-helper"; then
    printf "Erreur : l’échec du collecteur de remplacements a été accepté.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]
((${#PACKAGE_REPLACEMENTS[@]} == 0))
[[ "$PACKAGE_REPLACEMENTS_ERROR" == \
    "Le collecteur de remplacements a échoué avec le code 7. transaction preparation failed" ]]

if package_replacements_collect "$TEST_DIR/missing-helper"; then
    printf "Erreur : un collecteur de remplacements absent a été accepté.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]
[[ "$PACKAGE_REPLACEMENTS_ERROR" == \
    "Collecteur de remplacements absent ou non exécutable : ${TEST_DIR}/missing-helper." ]]

printf "Tous les tests du collecteur de remplacements ont réussi.\n"
