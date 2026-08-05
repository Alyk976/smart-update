#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck source=lib/package_removals.sh
source "./lib/package_removals.sh"

cat >"$TEST_DIR/empty-helper" <<'HELPER'
#!/usr/bin/env bash
exit 0
HELPER

cat >"$TEST_DIR/removals-helper" <<'HELPER'
#!/usr/bin/env bash
printf '%s\n' atk hwids atk
HELPER

cat >"$TEST_DIR/invalid-helper" <<'HELPER'
#!/usr/bin/env bash
printf '%s\n' 'invalid package name'
HELPER

cat >"$TEST_DIR/failing-helper" <<'HELPER'
#!/usr/bin/env bash
printf '%s\n' 'transaction preparation failed' >&2
exit 7
HELPER

chmod +x \
    "$TEST_DIR/empty-helper" \
    "$TEST_DIR/removals-helper" \
    "$TEST_DIR/invalid-helper" \
    "$TEST_DIR/failing-helper"

package_removals_collect "$TEST_DIR/empty-helper"

[[ -z "$PACKAGE_REMOVALS_ERROR" ]]
((${#PACKAGE_REMOVALS[@]} == 0))

package_removals_collect "$TEST_DIR/removals-helper"

[[ -z "$PACKAGE_REMOVALS_ERROR" ]]
((${#PACKAGE_REMOVALS[@]} == 2))
[[ "${PACKAGE_REMOVALS[0]}" == "atk" ]]
[[ "${PACKAGE_REMOVALS[1]}" == "hwids" ]]

if package_removals_collect "$TEST_DIR/invalid-helper"; then
    printf "Erreur : une sortie invalide a été acceptée.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 2 ]]
((${#PACKAGE_REMOVALS[@]} == 0))
[[ "$PACKAGE_REMOVALS_ERROR" == \
    "Nom de paquet invalide renvoyé par le collecteur : invalid package name." ]]

if package_removals_collect "$TEST_DIR/failing-helper"; then
    printf "Erreur : l’échec du collecteur a été accepté.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]
((${#PACKAGE_REMOVALS[@]} == 0))
[[ "$PACKAGE_REMOVALS_ERROR" == \
    "Le collecteur de suppressions a échoué avec le code 7. transaction preparation failed" ]]

if package_removals_collect "$TEST_DIR/missing-helper"; then
    printf "Erreur : un collecteur absent a été accepté.\n" >&2
    exit 1
else
    rc=$?
fi

[[ "$rc" -eq 1 ]]
[[ "$PACKAGE_REMOVALS_ERROR" == \
    "Collecteur de suppressions absent ou non exécutable : ${TEST_DIR}/missing-helper." ]]

printf "Tous les tests du collecteur de suppressions ont réussi.\n"
