#!/usr/bin/env bash
# shellcheck disable=SC2034

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
LOG_FILE="$TEST_DIR/log"
: >"$LOG_FILE"

# shellcheck source=lib/stability.sh
source "./lib/stability.sh"
# shellcheck source=lib/decision.sh
source "./lib/decision.sh"
# shellcheck source=lib/aur_updates.sh
source "./lib/aur_updates.sh"
# shellcheck source=lib/aur_phase.sh
source "./lib/aur_phase.sh"

EXIT_AUR_DISCOVERY_FAILED=31
EXIT_AUR_UPDATE_FAILED=32
CONFIG_DIR="$TEST_DIR"
PROJECT_ROOT=$(pwd)
cat >"$CONFIG_DIR/critical-packages.conf" <<'CONF'
linux
CONF

# Phase officielle mockée : trois candidats stables, dont linux critique.
UPDATE_PACKAGES=(linux glibc firefox)
OFFICIAL_REPOS=(core core extra)
for index in "${!UPDATE_PACKAGES[@]}"; do
    stability_candidate_is_stable \
        "${OFFICIAL_REPOS[$index]}" \
        "${UPDATE_PACKAGES[$index]}" \
        "1.0.${index}-1"
done
ALLOW_CRITICAL_UPDATES="yes"
# shellcheck source=lib/policies/20_critical_updates.sh
source "./lib/policies/20_critical_updates.sh"
policy_run
[[ "$POLICY_RESULT" == "WARNING" ]]
decision_reset
decision_add "$POLICY_RESULT" "$POLICY_REASON"
decision_allows_installation
printf '%s\n' "${UPDATE_PACKAGES[@]}" >"$TEST_DIR/official-installed"

# Phase AUR mockée : deux stables approuvés, deux instables exclus.
COLLECT_CALL=0
aur_updates_collect() {
    ((COLLECT_CALL += 1))
    AUR_UPDATES_ERROR=""
    AUR_UPDATE_NAMES=(google-chrome visual-studio-code-bin foo-git bar-beta)
    AUR_UPDATE_INSTALLED_VERSIONS=(1-1 1-1 1-1 1-1)
    AUR_UPDATE_CANDIDATE_VERSIONS=(2-1 2-1 2-1 2.0-beta1)
}
aur_user_run() {
    printf '%s\n' "$*" >"$TEST_DIR/yay-install"
}

aur_helper_capability_check() {
    AUR_HELPER_CAPABILITY="READY"
    return 0
}

MODE="guarded"
AUR_HELPER_PATH="yay"
AUR_RESULT="ANALYZED"
aur_phase_execute

[[ "$(tr '\n' ' ' <"$TEST_DIR/official-installed")" == \
    "linux glibc firefox " ]]
grep -Fqx 'yay -S --aur --needed --noconfirm --color never google-chrome visual-studio-code-bin' \
    "$TEST_DIR/yay-install"
if grep -Eq 'foo-git|bar-beta' "$TEST_DIR/yay-install"; then
    printf 'Erreur : candidat instable installé dans le workflow mocké.\n' >&2
    exit 1
fi
[[ "$AUR_RESULT" == "INSTALLED" ]]

printf 'Le workflow complet official + AUR mocké a réussi.\n'
