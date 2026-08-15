#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT

# shellcheck source=lib/aur_user.sh
source "$PROJECT_ROOT/lib/aur_user.sh"
# shellcheck source=lib/aur_helper.sh
source "$PROJECT_ROOT/lib/aur_helper.sh"

AUR_HELPER="yay"
AUR_USER="${1:-${SUDO_USER:-$(id -un)}}"
AUR_HELPER_PATH=""

if ! aur_helper_capability_check; then
    printf 'Capability: %s\n' "$AUR_HELPER_CAPABILITY"
    printf 'Detail    : %s\n' "$AUR_HELPER_CAPABILITY_ERROR"
    exit 1
fi

printf 'Capability: %s\n' "$AUR_HELPER_CAPABILITY"
printf 'Identity  : %s (%s:%s)\n' \
    "$AUR_EXEC_USER" "$AUR_EXEC_UID" "$AUR_EXEC_GID"
printf 'Home      : %s\n' "$AUR_EXEC_HOME"
printf 'Version   : %s\n' "$AUR_HELPER_VERSION"
printf 'Discovery : read-only yay -Qua --aur --color never\n'
aur_user_run_readonly "$AUR_HELPER_PATH" -Qua --aur --color never
