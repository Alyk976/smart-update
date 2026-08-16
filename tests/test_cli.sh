#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT

TEST_DIR=$(mktemp -d)
readonly TEST_DIR
trap 'rm -rf "$TEST_DIR"' EXIT

APP_DIR="${TEST_DIR}/app"
MOCK_BIN="${TEST_DIR}/mock-bin"
CLI="${APP_DIR}/bin/smart-update"
CONFIG_MARKER="${TEST_DIR}/config-loaded"
SIDE_EFFECT_MARKER="${TEST_DIR}/side-effect"

mkdir -p "${APP_DIR}/bin" "${APP_DIR}/lib" "$MOCK_BIN"
cp "${PROJECT_ROOT}/bin/smart-update" "$CLI"
cp "${PROJECT_ROOT}/lib/version.sh" "${APP_DIR}/lib/version.sh"

# La présence de config.sh force le layout de développement isolé. Si le
# module est chargé, le marqueur rend immédiatement la régression visible.
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "configuration chargée\n" >>"${SMART_UPDATE_CONFIG_MARKER:?}"' \
    >"${APP_DIR}/lib/config.sh"

# La version attendue vient de smart_update_package_version(), via son appel
# en lecture seule à pacman -Q.
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [[ "${1:-}" == "-Q" && "${2:-}" == "smart-update" ]]; then' \
    '    printf "%s\n" "smart-update 9.8.7-6"' \
    '    exit 0' \
    'fi' \
    'exit 64' \
    >"${MOCK_BIN}/pacman"
chmod +x "${MOCK_BIN}/pacman"

# Ces commandes couvrent les créations de répertoires, logs, verrou et
# rapports du bootstrap normal. Aucune ne doit être atteinte par le CLI court.
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "${0##*/}" >>"${SMART_UPDATE_SIDE_EFFECT_MARKER:?}"' \
    'exit 99' \
    >"${MOCK_BIN}/guard"
chmod +x "${MOCK_BIN}/guard"
for command_name in install mkdir touch chmod flock; do
    ln -s guard "${MOCK_BIN}/${command_name}"
done

fail() {
    printf 'Erreur test CLI : %s\n' "$1" >&2
    exit 1
}

run_cli() {
    local label="$1"
    shift

    RUN_STDOUT="${TEST_DIR}/${label}.stdout"
    RUN_STDERR="${TEST_DIR}/${label}.stderr"
    set +e
    SMART_UPDATE_CONFIG_MARKER="$CONFIG_MARKER" \
        SMART_UPDATE_SIDE_EFFECT_MARKER="$SIDE_EFFECT_MARKER" \
        PATH="${MOCK_BIN}:${PATH}" \
        bash "$CLI" "$@" >"$RUN_STDOUT" 2>"$RUN_STDERR"
    RUN_STATUS=$?
    set -e
}

assert_success() {
    ((RUN_STATUS == 0)) || fail "code de sortie inattendu : ${RUN_STATUS}."
}

assert_empty() {
    local file="$1"
    [[ ! -s "$file" ]] || fail "sortie inattendue dans ${file}."
}

assert_version_output() {
    assert_success
    assert_empty "$RUN_STDERR"
    [[ "$(<"$RUN_STDOUT")" == "9.8.7-6" ]] ||
        fail "la sortie de version doit contenir uniquement la version."
    [[ "$(wc -l <"$RUN_STDOUT")" -eq 1 ]] ||
        fail "la sortie de version doit tenir sur une ligne."
}

run_cli version-long --version
assert_version_output

run_cli version-short -V
assert_version_output

for help_option in --help -h; do
    run_cli "help-${help_option#-}" "$help_option"
    assert_success
    assert_empty "$RUN_STDERR"
    grep -Fq 'Usage : smart-update [OPTION]' "$RUN_STDOUT" ||
        fail "usage absent de l'aide ${help_option}."
    grep -Fq -- '-V, --version' "$RUN_STDOUT" ||
        fail "option de version absente de l'aide ${help_option}."
    grep -Fq -- '-h, --help' "$RUN_STDOUT" ||
        fail "option d'aide absente de l'aide ${help_option}."
done

run_cli unknown --option-inconnue
((RUN_STATUS == 2)) || fail "une option inconnue doit quitter avec le code 2."
assert_empty "$RUN_STDOUT"
grep -Fq -- 'Option inconnue : --option-inconnue' "$RUN_STDERR" ||
    fail "diagnostic explicite absent pour l'option inconnue."

[[ ! -e "$CONFIG_MARKER" ]] ||
    fail "le CLI court ne doit pas charger la configuration."
[[ ! -e "$SIDE_EFFECT_MARKER" ]] ||
    fail "le CLI court a exécuté une commande à effet de bord."

# Le dispatch doit précéder statiquement tout le bootstrap avec effets de bord.
dispatch_line=$(grep -nF 'dispatch_cli "$@" || exit $?' "${PROJECT_ROOT}/bin/smart-update" | cut -d: -f1)
for later_statement in \
    'readonly LOCK_FILE="/run/lock/smart-update.lock"' \
    'config_load "$CONFIG_FILE"' \
    'install -d -m 0750 "$STATE_DIR"' \
    'exec 9>"$LOCK_FILE"'; do
    later_line=$(grep -nF "$later_statement" "${PROJECT_ROOT}/bin/smart-update" | cut -d: -f1)
    [[ -n "$later_line" && "$dispatch_line" -lt "$later_line" ]] ||
        fail "le dispatch CLI doit précéder : ${later_statement}."
done

printf 'Tous les tests du CLI ont réussi.\n'
