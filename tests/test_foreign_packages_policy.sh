#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin"

cat >"$TEST_DIR/bin/pacman" <<'MOCK'
#!/usr/bin/env bash

if [[ "${1:-}" != "-Qqm" ]]; then
    exit 1
fi

if [[ -r "${MOCK_PACMAN_OUTPUT_FILE:-}" ]]; then
    cat "$MOCK_PACMAN_OUTPUT_FILE"
fi
MOCK

chmod +x "$TEST_DIR/bin/pacman"

export PATH="$TEST_DIR/bin:$PATH"
export MOCK_PACMAN_OUTPUT_FILE="$TEST_DIR/foreign-packages.txt"

# shellcheck source=lib/policies/30_foreign_packages.sh
source "./lib/policies/30_foreign_packages.sh"

# Aucun paquet étranger
: >"$MOCK_PACMAN_OUTPUT_FILE"

policy_run

[[ "$POLICY_NAME" == "foreign_packages" ]]
[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Aucun paquet étranger ou AUR installé." ]]
((${#POLICY_DETAILS[@]} == 0))

# Plusieurs paquets étrangers
cat >"$MOCK_PACMAN_OUTPUT_FILE" <<'PACKAGES'
google-chrome
paru
yay
PACKAGES

policy_run

[[ "$POLICY_NAME" == "foreign_packages" ]]
[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "$POLICY_REASON" == "3 paquet(s) étranger(s)/AUR détecté(s). Ils ne seront ni installés ni mis à jour par Smart Update." ]]
((${#POLICY_DETAILS[@]} == 3))
[[ "${POLICY_DETAILS[0]}" == "google-chrome" ]]
[[ "${POLICY_DETAILS[1]}" == "paru" ]]
[[ "${POLICY_DETAILS[2]}" == "yay" ]]

printf "Tous les tests de la politique des paquets étrangers ont réussi.\n"
