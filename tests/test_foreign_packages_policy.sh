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

# Aucun paquet Foreign inconnu
AUR_CONTEXT_ERROR=""
AUR_RESULT="ANALYZED"
UNKNOWN_FOREIGN_PACKAGES=()

policy_run

[[ "$POLICY_NAME" == "foreign_packages" ]]
[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Aucun paquet Foreign inconnu détecté." ]]
((${#POLICY_DETAILS[@]} == 0))

# Plusieurs paquets Foreign absents de l'AUR après classification effective
AUR_RESULT="ANALYZED"
UNKNOWN_FOREIGN_PACKAGES=(local-one local-two local-three)

policy_run

[[ "$POLICY_NAME" == "foreign_packages" ]]
[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "$POLICY_REASON" == "3 paquet(s) Foreign absent(s) de l'AUR. Aucune modification automatique." ]]
((${#POLICY_DETAILS[@]} == 3))
[[ "${POLICY_DETAILS[0]}" == "local-one" ]]
[[ "${POLICY_DETAILS[1]}" == "local-two" ]]
[[ "${POLICY_DETAILS[2]}" == "local-three" ]]

# AUR désactivé : les paquets Foreign ne doivent pas être présentés comme absents de l'AUR
AUR_RESULT="DISABLED"
UNKNOWN_FOREIGN_PACKAGES=(google-chrome yay paru)

policy_run

[[ "$POLICY_NAME" == "foreign_packages" ]]
[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "$POLICY_REASON" == "3 paquet(s) Foreign détecté(s). Recherche AUR désactivée ; classification AUR non effectuée. Aucune modification automatique." ]]
((${#POLICY_DETAILS[@]} == 3))
[[ "${POLICY_DETAILS[0]}" == "google-chrome" ]]
[[ "${POLICY_DETAILS[1]}" == "yay" ]]
[[ "${POLICY_DETAILS[2]}" == "paru" ]]

printf "Tous les tests de la politique des paquets étrangers ont réussi.\n"
