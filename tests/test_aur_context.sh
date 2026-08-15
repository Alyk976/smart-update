#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin"

cat >"$TEST_DIR/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
[[ "${1:-}" == "-Qqm" ]]
printf '%s\n' google-chrome local-private-package
printf '%s\n' paru-debug yay-debug
MOCK
chmod +x "$TEST_DIR/bin/pacman"
PATH="$TEST_DIR/bin:$PATH"
export PATH

aur_user_run_readonly() {
    local package="${*: -1}"
    case "$package" in
        google-chrome)
            printf 'Repository                    : aur\nName                          : google-chrome\n'
            return 0
            ;;
        local-private-package | paru-debug | yay-debug)
            printf ' -> No AUR package found for %s\n' "$package" >&2
            return 1
            ;;
    esac
}

# shellcheck source=lib/aur_context.sh
source "./lib/aur_context.sh"
aur_context_collect yay
[[ "${AUR_FOREIGN_PACKAGES[*]}" == "google-chrome" ]]
[[ "${AUR_UNKNOWN_FOREIGN[*]}" == \
    "local-private-package paru-debug yay-debug" ]]
[[ "${UNKNOWN_FOREIGN_PACKAGES[*]}" == "${AUR_UNKNOWN_FOREIGN[*]}" ]]

# Classification pure : absence exacte, AUR valide et erreurs réelles.
aur_context_classify_info_result \
    paru-debug 1 '' 'No AUR package found for paru-debug'
[[ "$AUR_INFO_CLASSIFICATION" == "FOREIGN_NON_AUR" ]]

aur_context_classify_info_result google-chrome 0 \
    $'Repository : aur\nName : google-chrome' ''
[[ "$AUR_INFO_CLASSIFICATION" == "AUR_PACKAGE" ]]

if aur_context_classify_info_result \
    paru-debug 1 '' 'No AUR package found for evil-package'; then
    printf 'Erreur : diagnostic concernant un autre paquet accepté.\n' >&2
    exit 1
fi
[[ "$AUR_INFO_CLASSIFICATION" == "ERROR" ]]

if aur_context_classify_info_result paru-debug 7 '' 'network timeout'; then
    printf 'Erreur : panne réseau classée NON_AUR.\n' >&2
    exit 1
fi
[[ "$AUR_INFO_CLASSIFICATION" == "ERROR" ]]

if aur_context_classify_info_result paru-debug 1 \
    'contradictory stdout' 'No AUR package found for paru-debug'; then
    printf 'Erreur : sortie contradictoire acceptée.\n' >&2
    exit 1
fi

printf 'Tous les tests du contexte AUR/Foreign ont réussi.\n'
