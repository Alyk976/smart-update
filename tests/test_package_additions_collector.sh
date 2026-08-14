#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck source=lib/package_additions.sh
source "./lib/package_additions.sh"

cat >"$TEST_DIR/empty-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--additions" ]]
exit 0
HELPER

cat >"$TEST_DIR/additions-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--additions" ]]
printf '%s\n' linux gexiv2-common linux
HELPER

cat >"$TEST_DIR/invalid-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--additions" ]]
printf '%s\n' 'invalid package name'
HELPER

cat >"$TEST_DIR/failing-helper" <<'HELPER'
#!/usr/bin/env bash
[[ "${1:-}" == "--additions" ]]
printf '%s\n' 'transaction preparation failed' >&2
exit 7
HELPER

chmod +x \
    "$TEST_DIR/empty-helper" \
    "$TEST_DIR/additions-helper" \
    "$TEST_DIR/invalid-helper" \
    "$TEST_DIR/failing-helper"

package_additions_collect "$TEST_DIR/empty-helper"

[[ -z "$PACKAGE_ADDITIONS_ERROR" ]]
((${#PACKAGE_ADDITIONS[@]} == 0))

package_additions_collect "$TEST_DIR/additions-helper"

[[ -z "$PACKAGE_ADDITIONS_ERROR" ]]
((${#PACKAGE_ADDITIONS[@]} == 2))
[[ "${PACKAGE_ADDITIONS[0]}" == "linux" ]]
[[ "${PACKAGE_ADDITIONS[1]}" == "gexiv2-common" ]]

if package_additions_collect "$TEST_DIR/invalid-helper"; then
    printf "Erreur : une sortie invalide a été acceptée.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 2 ]]
((${#PACKAGE_ADDITIONS[@]} == 0))
[[ "$PACKAGE_ADDITIONS_ERROR" == \
    "Nom de paquet invalide renvoyé par le collecteur d'ajouts : invalid package name." ]]

if package_additions_collect "$TEST_DIR/failing-helper"; then
    printf "Erreur : l’échec du collecteur a été accepté.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]
((${#PACKAGE_ADDITIONS[@]} == 0))
[[ "$PACKAGE_ADDITIONS_ERROR" == \
    "Le collecteur d'ajouts a échoué avec le code 7. transaction preparation failed" ]]

if package_additions_collect "$TEST_DIR/missing-helper"; then
    printf "Erreur : un collecteur absent a été accepté.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]
[[ "$PACKAGE_ADDITIONS_ERROR" == \
    "Collecteur d'ajouts absent ou non exécutable : ${TEST_DIR}/missing-helper." ]]

printf "Tous les tests du collecteur d'ajouts ont réussi.\n"
