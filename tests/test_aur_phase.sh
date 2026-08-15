#!/usr/bin/env bash
# shellcheck disable=SC2034

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
LOG_FILE="$TEST_DIR/log"
: >"$LOG_FILE"

# shellcheck source=lib/stability.sh
source "./lib/stability.sh"
# shellcheck source=lib/aur_updates.sh
source "./lib/aur_updates.sh"
# shellcheck source=lib/aur_helper.sh
source "./lib/aur_helper.sh"
# shellcheck source=lib/aur_phase.sh
source "./lib/aur_phase.sh"

EXIT_AUR_DISCOVERY_FAILED=31
EXIT_AUR_UPDATE_FAILED=32
AUR_HELPER_PATH="yay"
AUR_RESULT="ANALYZED"
MODE="audit"
INSTALL_CALLS_FILE="$TEST_DIR/install-calls"
: >"$INSTALL_CALLS_FILE"

aur_user_run() {
    printf '%s\n' "$*" >>"$INSTALL_CALLS_FILE"
    return "${MOCK_INSTALL_STATUS:-0}"
}

MOCK_CAPABILITY_STATUS="READY"
aur_helper_capability_check() {
    AUR_HELPER_CAPABILITY="$MOCK_CAPABILITY_STATUS"
    AUR_HELPER_CAPABILITY_ERROR="mock capability failure"
    [[ "$MOCK_CAPABILITY_STATUS" == "READY" ]]
}

# Audit : aucune installation yay.
AUR_UPDATE_NAMES=(google-chrome)
AUR_UPDATE_INSTALLED_VERSIONS=(1.0-1)
AUR_UPDATE_CANDIDATE_VERSIONS=(2.0-1)
AUR_APPROVED_PACKAGES=(google-chrome)
aur_phase_execute
[[ ! -s "$INSTALL_CALLS_FILE" ]]

# yay absent/phase indisponible ne casse pas le workflow officiel.
MODE="guarded"
AUR_RESULT="NOT_AVAILABLE"
aur_phase_execute
[[ ! -s "$INSTALL_CALLS_FILE" ]]

pacman() { return 0; }
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="definitely-missing-yay"
AUR_USER="auto"
MOCK_CAPABILITY_STATUS="NOT_INSTALLED"
aur_phase_prepare
[[ "$AUR_RESULT" == "NOT_AVAILABLE" ]]
[[ "$AUR_PHASE_ERROR" == "mock capability failure" ]]
AUR_HELPER_PATH="yay"
MOCK_CAPABILITY_STATUS="READY"

COLLECT_CALL=0
MOCK_CHANGE="no"
aur_updates_collect() {
    ((COLLECT_CALL += 1))
    AUR_UPDATES_ERROR=""
    AUR_UPDATE_NAMES=(google-chrome visual-studio-code-bin foo-git bar-beta)
    AUR_UPDATE_INSTALLED_VERSIONS=(1-1 1-1 1-1 1-1)
    AUR_UPDATE_CANDIDATE_VERSIONS=(2-1 2-1 2-1 2.0-beta1)
    if [[ "$MOCK_CHANGE" == "yes" && "$COLLECT_CALL" -eq 2 ]]; then
        AUR_UPDATE_CANDIDATE_VERSIONS[0]=3-1
    fi
}

# Workflow mocké : seuls les deux paquets stables ciblés atteignent yay.
PACKAGE_CANDIDATE_NAMES=(linux pacman firefox)
aur_helper_detect_official_recheck
[[ "$AUR_HELPER_RECHECK_REQUIRED" == "yes" ]]
AUR_RESULT="ANALYZED"
COLLECT_CALL=0
aur_phase_execute
grep -Fqx 'yay -S --aur --needed --noconfirm --color never google-chrome visual-studio-code-bin' \
    "$INSTALL_CALLS_FILE"
if grep -Eq 'foo-git|bar-beta|--devel' "$INSTALL_CALLS_FILE"; then
    printf 'Erreur : candidat AUR interdit transmis à yay.\n' >&2
    exit 1
fi
if grep -Eq 'paru-debug|yay-debug|local-private-package' "$INSTALL_CALLS_FILE"; then
    printf 'Erreur : paquet Foreign inconnu transmis à yay -S.\n' >&2
    exit 1
fi
[[ "$AUR_RESULT" == "INSTALLED" ]]

# Pacman/libalpm mis à jour et yay devenu incompatible : phase différée,
# aucun appel d'installation et résultat partiel non nul.
: >"$INSTALL_CALLS_FILE"
AUR_RESULT="ANALYZED"
MOCK_CAPABILITY_STATUS="INCOMPATIBLE"
if aur_phase_execute; then
    printf 'Erreur : incompatibilité yay post-libalpm ignorée.\n' >&2
    exit 1
else
    rc=$?
fi
[[ "$rc" -eq 31 ]]
[[ "$AUR_RESULT" == "DEFERRED_HELPER_INCOMPATIBLE" ]]
[[ "$AUR_HELPER_POST_UPDATE_STATUS" == "INCOMPATIBLE" ]]
[[ ! -s "$INSTALL_CALLS_FILE" ]]
MOCK_CAPABILITY_STATUS="READY"

# Le même recheck réussi après une mise à jour de pacman autorise l'AUR.
: >"$INSTALL_CALLS_FILE"
AUR_RESULT="ANALYZED"
COLLECT_CALL=0
aur_phase_execute
[[ "$AUR_HELPER_POST_UPDATE_STATUS" == "READY" ]]
grep -Fqx 'yay -S --aur --needed --noconfirm --color never google-chrome visual-studio-code-bin' \
    "$INSTALL_CALLS_FILE"

# Changement de version entre analyse et installation : abandon.
: >"$INSTALL_CALLS_FILE"
AUR_RESULT="ANALYZED"
COLLECT_CALL=0
MOCK_CHANGE="yes"
if aur_phase_execute; then
    printf 'Erreur : changement TOCTOU accepté.\n' >&2
    exit 1
else
    rc=$?
fi
[[ "$rc" -eq 31 ]]
[[ ! -s "$INSTALL_CALLS_FILE" ]]

# Échec yay après phase officielle : RC 32 et résultat partiel FAILED.
MOCK_CHANGE="no"
MOCK_INSTALL_STATUS=9
AUR_RESULT="ANALYZED"
COLLECT_CALL=0
if aur_phase_execute; then
    printf "Erreur : échec d'installation AUR ignoré.\n" >&2
    exit 1
else
    rc=$?
fi
[[ "$rc" -eq 32 ]]
[[ "$AUR_RESULT" == "FAILED" ]]

grep -Fq "'yay: update stable AUR packages'" PKGBUILD
depends_line=$(grep -E '^depends=' PKGBUILD)
[[ "$depends_line" != *yay* ]]

printf 'Tous les tests de la phase AUR mockée ont réussi.\n'
