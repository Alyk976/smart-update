#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin"

cat >"$TEST_DIR/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
[[ "${1:-}" == "-Qqm" ]]
printf '%s\n' google-chrome local-private-package
MOCK
chmod +x "$TEST_DIR/bin/pacman"
PATH="$TEST_DIR/bin:$PATH"
export PATH

aur_user_run() {
    local package="${*: -1}"
    if [[ "$package" == "google-chrome" ]]; then
        printf 'Repository                    : aur\nName                          : google-chrome\n'
        return 0
    fi
    printf ' -> No AUR package found for %s\n' "$package"
    return 1
}

# shellcheck source=lib/aur_context.sh
source "./lib/aur_context.sh"
aur_context_collect yay
[[ "${AUR_FOREIGN_PACKAGES[*]}" == "google-chrome" ]]
[[ "${UNKNOWN_FOREIGN_PACKAGES[*]}" == "local-private-package" ]]

printf 'Tous les tests du contexte AUR/Foreign ont réussi.\n'
