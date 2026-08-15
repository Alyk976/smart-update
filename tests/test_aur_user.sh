#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/home"

cat >"$TEST_DIR/bin/getent" <<MOCK
#!/usr/bin/env bash
[[ "\${1:-}" == "passwd" ]]
case "\${2:-}" in
    mahadi) printf 'mahadi:x:1000:1000::${TEST_DIR}/home:/bin/bash\\n' ;;
    root) printf 'root:x:0:0::/root:/bin/bash\\n' ;;
    *) exit 2 ;;
esac
MOCK
chmod +x "$TEST_DIR/bin/getent"
PATH="$TEST_DIR/bin:$PATH"
export PATH

# shellcheck source=lib/aur_user.sh
source "./lib/aur_user.sh"

if aur_user_resolve root; then
    printf 'Erreur : AUR_USER=root accepté.\n' >&2
    exit 1
fi

aur_user_resolve mahadi
[[ "$AUR_EXEC_USER" == "mahadi" ]]
[[ "$AUR_EXEC_UID" == "1000" ]]
[[ "$AUR_EXEC_HOME" == "$TEST_DIR/home" ]]

cat >"$TEST_DIR/bin/capture-env" <<'MOCK'
#!/usr/bin/env bash
printf '%s|%s|%s|%s|%s\n' \
    "$SUDO_USER" "$SUDO_UID" "$SUDO_GID" "$HOME" "$USER"
MOCK
chmod +x "$TEST_DIR/bin/capture-env"
[[ "$(aur_user_run "$TEST_DIR/bin/capture-env")" == \
    "mahadi|1000|1000|$TEST_DIR/home|mahadi" ]]

cat >"$TEST_DIR/bin/capture-readonly" <<'MOCK'
#!/usr/bin/env bash
printf '%s|%s|%s|%s\n' "$(id -u)" "$HOME" "$USER" "$LOGNAME"
MOCK
chmod +x "$TEST_DIR/bin/capture-readonly"
runuser() {
    [[ "${1:-}" == "-u" && "${2:-}" == "mahadi" && "${3:-}" == "--" ]]
    shift 3
    "$@"
}
readonly_context=$(aur_user_run_readonly "$TEST_DIR/bin/capture-readonly")
[[ "$readonly_context" == "$(id -u)|$TEST_DIR/home|mahadi|mahadi" ]]

if rg -n -- '--sudoloop|sudoers' lib/aur_user.sh lib/aur_phase.sh \
    >/dev/null; then
    printf 'Erreur : élévation ou sudoers interdit présent dans le chemin AUR.\n' >&2
    exit 1
fi
readonly_function=$(sed -n '/^aur_user_run_readonly()/,/^}/p' lib/aur_user.sh)
install_function=$(sed -n '/^aur_user_run()/,/^}/p' lib/aur_user.sh)
[[ "$readonly_function" == *'runuser -u'* ]]
[[ "$install_function" != *runuser* ]]
[[ "$install_function" == *'SUDO_USER="$AUR_EXEC_USER"'* ]]

SUDO_USER=mahadi
export SUDO_USER
aur_user_resolve auto
[[ "$AUR_EXEC_USER" == "mahadi" ]]

unset SUDO_USER
if aur_user_resolve auto; then
    printf 'Erreur : auto sans SUDO_USER a inventé un utilisateur.\n' >&2
    exit 1
fi
[[ -z "$AUR_EXEC_USER" ]]

printf 'Tous les tests de résolution AUR_USER ont réussi.\n'
