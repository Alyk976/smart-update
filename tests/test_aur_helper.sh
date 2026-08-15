#!/usr/bin/env bash
# shellcheck disable=SC2034

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin"

# shellcheck source=lib/aur_helper.sh
source "./lib/aur_helper.sh"

AUR_HELPER="yay"
AUR_USER="tester"
AUR_HELPER_PATH=""
PACKAGE_CANDIDATE_NAMES=()
MOCK_USER_STATUS=0
MOCK_VERSION_STATUS=0
MOCK_VERSION='yay v13.0.1 - libalpm v16.0.1'

aur_user_resolve() {
    if ((MOCK_USER_STATUS != 0)); then
        AUR_USER_ERROR="invalid AUR user"
        return 1
    fi
}

aur_user_run_readonly() {
    case "${2:-}" in
        --version)
            ((MOCK_VERSION_STATUS == 0)) || return "$MOCK_VERSION_STATUS"
            printf '%s\n' "$MOCK_VERSION"
            ;;
        --help)
            printf '%s\n' '--aur --color --needed --noconfirm'
            ;;
        *) return 2 ;;
    esac
}

# Binaire absent.
AUR_HELPER="definitely-missing-yay"
if aur_helper_capability_check; then
    printf 'Erreur : yay absent déclaré opérationnel.\n' >&2
    exit 1
fi
[[ "$AUR_HELPER_CAPABILITY" == "NOT_INSTALLED" ]]

# Binaire présent mais --version/libalpm échoue.
cat >"$TEST_DIR/bin/yay" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$TEST_DIR/bin/yay"
AUR_HELPER="$TEST_DIR/bin/yay"
MOCK_VERSION_STATUS=9
if aur_helper_capability_check; then
    printf 'Erreur : yay incompatible déclaré opérationnel.\n' >&2
    exit 1
fi
[[ "$AUR_HELPER_CAPABILITY" == "INCOMPATIBLE" ]]

# Identité invalide.
MOCK_VERSION_STATUS=0
MOCK_USER_STATUS=1
if aur_helper_capability_check; then
    printf 'Erreur : identité AUR invalide acceptée.\n' >&2
    exit 1
fi
[[ "$AUR_HELPER_CAPABILITY" == "USER_CONTEXT_UNAVAILABLE" ]]

# yay 13/libalpm et options attendues : READY.
MOCK_USER_STATUS=0
aur_helper_capability_check
[[ "$AUR_HELPER_CAPABILITY" == "READY" ]]

PACKAGE_CANDIDATE_NAMES=(linux pacman firefox)
aur_helper_detect_official_recheck
[[ "$AUR_HELPER_RECHECK_REQUIRED" == "yes" ]]
PACKAGE_CANDIDATE_NAMES=(linux firefox)
aur_helper_detect_official_recheck
[[ "$AUR_HELPER_RECHECK_REQUIRED" == "no" ]]

printf 'Tous les tests de capacité du helper AUR ont réussi.\n'
