#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/stability.sh
source "./lib/stability.sh"
# shellcheck source=lib/aur_updates.sh
source "./lib/aur_updates.sh"

MOCK_YAY_STATUS=0
MOCK_YAY_OUTPUT=""
MOCK_YAY_ERROR=""
aur_user_run_readonly() {
    printf '%s\n' "$MOCK_YAY_OUTPUT"
    printf '%s\n' "$MOCK_YAY_ERROR" >&2
    return "$MOCK_YAY_STATUS"
}

MOCK_YAY_OUTPUT=$'google-chrome 149.0-1 -> 151.0-1 [3d1h]\nvisual-studio-code-bin 1.2.3-1 -> 1.2.4-1\nfoo-git 1.0.r1-1 -> 1.0.r2-1\nbar 1.0-1 -> 2.0-beta1\nbaz 2.0-1 -> 3.0-rc2\ndevpkg 1-1 -> 1-dev.2\nnightpkg 1-1 -> 1-nightly-1\nsnapshotpkg 1-1 -> 1-snapshot.1'
aur_updates_collect yay
aur_updates_classify

((${#AUR_UPDATE_NAMES[@]} == 8))
[[ "${AUR_APPROVED_PACKAGES[*]}" == \
    "google-chrome visual-studio-code-bin" ]]
((${#AUR_SKIPPED_UNSTABLE[@]} == 6))
[[ "${AUR_APPROVED_PACKAGES[*]}" != *foo-git* ]]

# Un avertissement stderr ne doit jamais entrer dans le parseur stdout.
MOCK_YAY_OUTPUT='google-chrome 149.0-1 -> 151.0-1'
MOCK_YAY_ERROR=' -> diagnostic warning only'
aur_updates_collect yay
[[ "${AUR_UPDATE_NAMES[*]}" == "google-chrome" ]]

MOCK_YAY_OUTPUT='not a supported yay line'
if aur_updates_collect yay; then
    printf 'Erreur : sortie yay invalide acceptée.\n' >&2
    exit 1
fi
((${#AUR_UPDATE_NAMES[@]} == 0))
[[ -n "$AUR_UPDATES_ERROR" ]]

MOCK_YAY_STATUS=7
MOCK_YAY_OUTPUT='must-not-be-used'
MOCK_YAY_ERROR='network error'
if aur_updates_collect yay; then
    printf 'Erreur : échec yay accepté.\n' >&2
    exit 1
fi
((${#AUR_UPDATE_NAMES[@]} == 0))
[[ "$AUR_UPDATES_ERROR" == *'network error'* ]]

printf 'Tous les tests du collecteur AUR ont réussi.\n'
