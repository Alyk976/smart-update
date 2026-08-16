#!/usr/bin/env bash
# shellcheck disable=SC1112

set -Eeuo pipefail

if ((EUID != 0)); then
    printf '%s\n' 'Ce script doit être exécuté avec sudo/root.' >&2
    exit 1
fi

readonly CONFIG_FILE="/etc/smart-update/smart-update.conf"
readonly CONFIG_MODULE="/usr/lib/smart-update/config.sh"
readonly REPORT_DIR="/var/log/smart-update/reports"
readonly SMART_UPDATE_BIN="/usr/bin/smart-update"
readonly REAL_PACMAN="/usr/bin/pacman"
readonly TIMER_UNIT="smart-update.timer"
readonly SERVICE_UNIT="smart-update.service"
readonly SAFE_CHECKUPDATES_DB="/tmp/checkup-db-0/"

TEST_TMPDIR=$(mktemp -d /tmp/smart-update-guarded.XXXXXXXX)
readonly TEST_TMPDIR
readonly CONFIG_BACKUP="${TEST_TMPDIR}/smart-update.conf.original"
readonly GUARD_BIN="${TEST_TMPDIR}/guard-bin"
readonly PACMAN_GUARD_LOG="${TEST_TMPDIR}/pacman-guard.log"
readonly YAY_GUARD_LOG="${TEST_TMPDIR}/yay-guard.log"

backup_ready="no"
config_restored_identical="non vérifié"
timer_state_recorded="no"
timer_stop_attempted="no"
test_completed="no"
integrity_before_checked="no"
packages_before_ready="no"
smart_update_version="inconnue"
guarded_rc="non exécuté"
verdict_block_confirmed="non"
package_count_before="inconnu"
package_count_after="inconnu"
packages_unchanged="non vérifié"
new_report="aucun"
initial_mode="inconnu"
final_mode="inconnu"
original_config_sha=""
original_config_metadata=""
timer_enabled_initial="inconnu"
timer_active_initial="inconnu"
timer_enabled_final="inconnu"
timer_active_final="inconnu"

die() {
    printf 'ERREUR : %s\n' "$*" >&2
    exit 1
}

timer_enabled_state() {
    systemctl is-enabled "$TIMER_UNIT" 2>/dev/null || true
}

timer_active_state() {
    systemctl is-active "$TIMER_UNIT" 2>/dev/null || true
}

restore_timer_enabled_state() {
    local current_state

    current_state=$(timer_enabled_state)
    if [[ "$current_state" == "$timer_enabled_initial" ]]; then
        return 0
    fi

    case "$timer_enabled_initial" in
        enabled)
            systemctl unmask "$TIMER_UNIT" || return 1
            systemctl enable "$TIMER_UNIT" || return 1
            ;;
        enabled-runtime)
            systemctl unmask --runtime "$TIMER_UNIT" || return 1
            systemctl enable --runtime "$TIMER_UNIT" || return 1
            ;;
        disabled)
            systemctl unmask "$TIMER_UNIT" || return 1
            systemctl disable "$TIMER_UNIT" || return 1
            ;;
        masked)
            systemctl mask "$TIMER_UNIT" || return 1
            ;;
        masked-runtime)
            systemctl mask --runtime "$TIMER_UNIT" || return 1
            ;;
        *)
            printf 'ERREUR CRITIQUE : impossible de restaurer automatiquement l’état enabled %s.\n' \
                "$timer_enabled_initial" >&2
            return 1
            ;;
    esac

    [[ "$(timer_enabled_state)" == "$timer_enabled_initial" ]]
}

restore_timer_active_state() {
    case "$timer_active_initial" in
        active)
            systemctl start "$TIMER_UNIT"
            ;;
        inactive)
            systemctl stop "$TIMER_UNIT"
            ;;
        *)
            printf 'ERREUR CRITIQUE : état active initial non restaurable : %s.\n' \
                "$timer_active_initial" >&2
            return 1
            ;;
    esac
}

count_reports() {
    find "$REPORT_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'report-*.txt' \
        -printf '.' |
        wc -c
}

cleanup() {
    local original_status=$?
    local cleanup_status=0
    local restored_sha=""
    local restored_metadata=""

    trap - EXIT INT TERM HUP
    set +e

    if [[ "$backup_ready" == "yes" ]]; then
        if cp -a -- "$CONFIG_BACKUP" "$CONFIG_FILE"; then
            restored_sha=$(sha256sum "$CONFIG_FILE" | awk '{print $1}')
            restored_metadata=$(stat -c '%a|%u|%g|%s|%y' "$CONFIG_FILE")
            final_mode=$(grep -E '^[[:space:]]*MODE=' "$CONFIG_FILE" || true)

            if [[ "$restored_sha" == "$original_config_sha" \
                && "$restored_metadata" == "$original_config_metadata" ]]; then
                config_restored_identical="oui"
            else
                config_restored_identical="non"
                printf '%s\n' \
                    'ERREUR CRITIQUE : SHA256 ou métadonnées de la configuration restaurée incorrects.' >&2
                cleanup_status=1
            fi
        else
            config_restored_identical="non"
            printf '%s\n' \
                'ERREUR CRITIQUE : restauration de la configuration impossible.' >&2
            cleanup_status=1
        fi
    fi

    # Le snapshot final est pris tant que le timer est encore arrêté afin
    # qu’une éventuelle reprise normale du timer ne soit pas attribuée au test.
    if [[ "$packages_before_ready" == "yes" ]]; then
        if LC_ALL=C "$REAL_PACMAN" -Q | LC_ALL=C sort \
            >"${TEST_TMPDIR}/packages.after"; then
            package_count_after=$(wc -l <"${TEST_TMPDIR}/packages.after")
            if diff -u \
                "${TEST_TMPDIR}/packages.before" \
                "${TEST_TMPDIR}/packages.after"; then
                packages_unchanged="oui"
            else
                packages_unchanged="non"
                printf '%s\n' \
                    'ERREUR CRITIQUE : la liste ou la version des paquets a changé.' >&2
                cleanup_status=1
            fi
        else
            packages_unchanged="non vérifiable"
            printf '%s\n' \
                'ERREUR CRITIQUE : snapshot final des paquets impossible.' >&2
            cleanup_status=1
        fi
    fi

    if [[ "$integrity_before_checked" == "yes" ]]; then
        if ! "$REAL_PACMAN" -Qkk smart-update; then
            printf '%s\n' \
                'ERREUR CRITIQUE : pacman -Qkk smart-update a échoué après restauration.' >&2
            cleanup_status=1
        fi
    fi

    if [[ "$timer_state_recorded" == "yes" ]]; then
        if [[ "$timer_stop_attempted" == "yes" ]]; then
            if [[ "$config_restored_identical" != "oui" ]]; then
                printf '%s\n' \
                    'ERREUR CRITIQUE : timer laissé arrêté car la configuration sûre n’a pas été restaurée.' >&2
                cleanup_status=1
            else
                restore_timer_enabled_state || cleanup_status=1
                restore_timer_active_state || cleanup_status=1
            fi
        fi

        timer_enabled_final=$(timer_enabled_state)
        timer_active_final=$(timer_active_state)

        if [[ "$timer_enabled_final" != "$timer_enabled_initial" ]]; then
            printf '%s\n' \
                'ERREUR CRITIQUE : état enabled du timer non restauré.' >&2
            cleanup_status=1
        fi
        if [[ "$timer_active_final" != "$timer_active_initial" ]]; then
            printf '%s\n' \
                'ERREUR CRITIQUE : état active du timer non restauré.' >&2
            cleanup_status=1
        fi
    fi

    printf '\n====================================================\n'
    printf '%s\n' ' Résumé du test guarded réel 1.1.0'
    printf '====================================================\n'
    printf 'Version Smart Update              : %s\n' "$smart_update_version"
    printf 'RC du test guarded                : %s\n' "$guarded_rc"
    printf 'Verdict BLOCK confirmé            : %s\n' "$verdict_block_confirmed"
    printf 'Nombre de paquets avant           : %s\n' "$package_count_before"
    printf 'Nombre de paquets après           : %s\n' "$package_count_after"
    printf 'Aucun paquet modifié              : %s\n' "$packages_unchanged"
    printf 'Rapport généré                    : %s\n' "$new_report"
    printf 'Configuration restaurée identique : %s\n' \
        "$config_restored_identical"
    printf 'MODE initial                      : %s\n' "$initial_mode"
    printf 'MODE final                        : %s\n' "$final_mode"
    printf 'Timer enabled initial/final       : %s / %s\n' \
        "$timer_enabled_initial" "$timer_enabled_final"
    printf 'Timer active initial/final        : %s / %s\n' \
        "$timer_active_initial" "$timer_active_final"

    if ((cleanup_status == 0)); then
        if [[ "$TEST_TMPDIR" == /tmp/smart-update-guarded.* \
            && -d "$TEST_TMPDIR" ]]; then
            rm -rf -- "$TEST_TMPDIR"
        else
            printf 'ERREUR CRITIQUE : répertoire temporaire invalide : %s\n' \
                "$TEST_TMPDIR" >&2
            cleanup_status=1
        fi
    else
        printf 'Artefacts de récupération conservés dans : %s\n' \
            "$TEST_TMPDIR" >&2
    fi

    if ((cleanup_status != 0)); then
        printf '%s\n' 'TEST ÉCHOUÉ : inspection manuelle requise.' >&2
        exit 1
    fi
    if ((original_status != 0)); then
        printf '%s\n' 'TEST ÉCHOUÉ : état restauré, voir le diagnostic précédent.' >&2
        exit "$original_status"
    fi
    if [[ "$test_completed" != "yes" ]]; then
        printf '%s\n' 'TEST ÉCHOUÉ : scénario incomplet.' >&2
        exit 1
    fi

    printf '%s\n' 'TEST RÉUSSI : aucune installation de paquet détectée.'
    exit 0
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

set_config_line() {
    local key="${1:?}"
    local replacement="${2:?}"
    local count

    count=$(grep -Ec "^[[:space:]]*${key}=" "$CONFIG_FILE")
    [[ "$count" -eq 1 ]] ||
        die "nombre de lignes ${key} incorrect : ${count}."
    sed -i -E \
        "s|^[[:space:]]*${key}=.*|${replacement}|" \
        "$CONFIG_FILE"
}

create_command_guards() {
    mkdir -m 0700 "$GUARD_BIN"
    : >"$PACMAN_GUARD_LOG"
    : >"$YAY_GUARD_LOG"

    cat >"${GUARD_BIN}/pacman" <<'PACMAN_GUARD'
#!/usr/bin/env bash
set -Eeuo pipefail

reject() {
    {
        printf 'pacman refusé :'
        printf ' %q' "$@"
        printf '\n'
    } >>"${SMART_UPDATE_PACMAN_GUARD_LOG:?}"
    exit 125
}

case "${1:-}" in
    -Q)
        if (($# == 1)) \
            || (($# == 2)) && [[ "$2" == "smart-update" ]]; then
            exec /usr/bin/pacman "$@"
        fi
        ;;
    -Qq | -Qqe | -Qm | -Qmq | -Qqm)
        (($# == 1)) && exec /usr/bin/pacman "$@"
        ;;
    -Sy)
        if (($# == 6)) \
            && [[ "$2" == "--disable-sandbox-filesystem" \
                && "$3" == "--dbpath" \
                && "$4" == "${SMART_UPDATE_SAFE_DBPATH:?}" \
                && "$5" == "--logfile" \
                && "$6" == "/dev/null" ]]; then
            exec /usr/bin/pacman "$@"
        fi
        ;;
    -Qu)
        if (($# == 3)) \
            && [[ "$2" == "--dbpath" \
                && "$3" == "${SMART_UPDATE_SAFE_DBPATH:?}" ]]; then
            exec /usr/bin/pacman "$@"
        fi
        if (($# == 5)) \
            && [[ "$2" == "--dbpath" \
                && "$3" == "${SMART_UPDATE_SAFE_DBPATH:?}" \
                && "$4" == "--color" \
                && "$5" == "always" ]]; then
            exec /usr/bin/pacman "$@"
        fi
        ;;
esac

reject "$@"
PACMAN_GUARD

    cat >"${GUARD_BIN}/yay" <<'YAY_GUARD'
#!/usr/bin/env bash
set -Eeuo pipefail
{
    printf 'yay refusé :'
    printf ' %q' "$@"
    printf '\n'
} >>"${SMART_UPDATE_YAY_GUARD_LOG:?}"
exit 125
YAY_GUARD

    chmod 0700 "${GUARD_BIN}/pacman" "${GUARD_BIN}/yay"
}

printf '%s\n' '--- Préconditions ---'
[[ -x "$REAL_PACMAN" ]] || die "pacman réel absent : ${REAL_PACMAN}"
[[ -x "$SMART_UPDATE_BIN" ]] ||
    die "Smart Update installé absent : ${SMART_UPDATE_BIN}"
[[ -r "$CONFIG_MODULE" ]] ||
    die "module de configuration installé absent : ${CONFIG_MODULE}"

smart_update_query=$("$REAL_PACMAN" -Q smart-update) ||
    die "le paquet smart-update n'est pas installé."
[[ "$smart_update_query" =~ ^smart-update[[:space:]]+1\.1\.0\.dev-[^[:space:]]+$ ]] ||
    die "version de développement 1.1.0 inattendue : ${smart_update_query}"
smart_update_version="$smart_update_query"

service_state=$(systemctl is-active "$SERVICE_UNIT" 2>/dev/null || true)
[[ "$service_state" == "inactive" ]] ||
    die "${SERVICE_UNIT} doit être inactive : ${service_state}"

timer_enabled_initial=$(timer_enabled_state)
timer_active_initial=$(timer_active_state)
case "$timer_enabled_initial" in
    enabled | enabled-runtime | disabled | masked | masked-runtime \
        | static | indirect | generated | transient | alias | linked \
        | linked-runtime)
        ;;
    *)
        die "état enabled du timer non pris en charge : ${timer_enabled_initial}"
        ;;
esac
case "$timer_active_initial" in
    active | inactive)
        ;;
    *)
        die "le timer doit avoir un état stable active/inactive : ${timer_active_initial}"
        ;;
esac
printf '%s\n' "$timer_enabled_initial" >"${TEST_TMPDIR}/timer.enabled.original"
printf '%s\n' "$timer_active_initial" >"${TEST_TMPDIR}/timer.active.original"
timer_state_recorded="yes"

[[ -f "$CONFIG_FILE" ]] || die "configuration absente : ${CONFIG_FILE}"
bash -n "$CONFIG_FILE" || die "syntaxe invalide dans ${CONFIG_FILE}."
initial_mode=$(grep -E '^[[:space:]]*MODE=' "$CONFIG_FILE") ||
    die "MODE absent de la configuration."

original_config_sha=$(sha256sum "$CONFIG_FILE" | awk '{print $1}')
original_config_metadata=$(stat -c '%a|%u|%g|%s|%y' "$CONFIG_FILE")
cp -a -- "$CONFIG_FILE" "$CONFIG_BACKUP"
[[ "$(sha256sum "$CONFIG_BACKUP" | awk '{print $1}')" == \
    "$original_config_sha" ]] || die "copie temporaire de configuration invalide."
[[ "$(stat -c '%a|%u|%g|%s|%y' "$CONFIG_BACKUP")" == \
    "$original_config_metadata" ]] ||
    die "métadonnées de la copie de configuration invalides."
backup_ready="yes"

printf '%s\n' '--- Arrêt temporaire du timer ---'
timer_stop_attempted="yes"
systemctl stop "$TIMER_UNIT"
[[ "$(timer_active_state)" == "inactive" ]] ||
    die "timer toujours actif après arrêt."
service_state=$(systemctl is-active "$SERVICE_UNIT" 2>/dev/null || true)
[[ "$service_state" == "inactive" ]] ||
    die "${SERVICE_UNIT} actif après arrêt du timer : ${service_state}"

"$REAL_PACMAN" -Qkk smart-update ||
    die "pacman -Qkk smart-update a échoué avant le scénario."
integrity_before_checked="yes"

LC_ALL=C "$REAL_PACMAN" -Q | LC_ALL=C sort \
    >"${TEST_TMPDIR}/packages.before"
packages_before_ready="yes"
package_count_before=$(wc -l <"${TEST_TMPDIR}/packages.before")

[[ -d "$REPORT_DIR" ]] || die "répertoire des rapports absent."
report_count_before=$(count_reports)
find "$REPORT_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'report-*.txt' \
    -printf '%f\n' |
    LC_ALL=C sort >"${TEST_TMPDIR}/reports.before"

printf '%s\n' '--- Configuration BLOCK déterministe temporaire ---'
set_config_line MODE 'MODE="guarded"'
set_config_line ENABLE_AUR_UPDATES 'ENABLE_AUR_UPDATES="no"'
set_config_line ALLOW_OVERWRITE 'ALLOW_OVERWRITE="yes"'
set_config_line REPORT_RETENTION_DAYS 'REPORT_RETENTION_DAYS=365000'

bash -n "$CONFIG_FILE" || die "configuration temporaire syntaxiquement invalide."
bash -c \
    'set -Eeuo pipefail; source "$1"; config_load "$2"' \
    _ "$CONFIG_MODULE" "$CONFIG_FILE" ||
    die "configuration temporaire refusée par Smart Update 1.1.0."

grep -Fqx 'MODE="guarded"' "$CONFIG_FILE" ||
    die "MODE guarded non appliqué."
grep -Fqx 'ENABLE_AUR_UPDATES="no"' "$CONFIG_FILE" ||
    die "désactivation AUR non appliquée."
grep -Fqx 'ALLOW_OVERWRITE="yes"' "$CONFIG_FILE" ||
    die "BLOCK overwrite_guard non configuré."
grep -Fqx 'REPORT_RETENTION_DAYS=365000' "$CONFIG_FILE" ||
    die "protection des rapports existants non appliquée."

create_command_guards

printf '%s\n' '--- Exécution réelle du chemin guarded protégé ---'
set +e
SMART_UPDATE_PACMAN_GUARD_LOG="$PACMAN_GUARD_LOG" \
    SMART_UPDATE_YAY_GUARD_LOG="$YAY_GUARD_LOG" \
    SMART_UPDATE_SAFE_DBPATH="$SAFE_CHECKUPDATES_DB" \
    PATH="${GUARD_BIN}:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin" \
    "$SMART_UPDATE_BIN"
guarded_rc=$?
set -e

[[ ! -s "$PACMAN_GUARD_LOG" ]] || {
    sed -n '1,40p' "$PACMAN_GUARD_LOG" >&2
    die "Smart Update a tenté un appel pacman interdit."
}
[[ ! -s "$YAY_GUARD_LOG" ]] || {
    sed -n '1,40p' "$YAY_GUARD_LOG" >&2
    die "Smart Update a tenté d'appeler yay malgré ENABLE_AUR_UPDATES=no."
}
[[ "$guarded_rc" -eq 29 ]] ||
    die "code retour inattendu : ${guarded_rc}, attendu : 29."

printf '%s\n' '--- Vérification de l’unique nouveau rapport ---'
report_count_after=$(count_reports)
[[ "$report_count_after" -eq $((report_count_before + 1)) ]] ||
    die "nombre de rapports inattendu : ${report_count_before} avant, ${report_count_after} après."

find "$REPORT_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'report-*.txt' \
    -printf '%f\n' |
    LC_ALL=C sort >"${TEST_TMPDIR}/reports.after"

mapfile -t removed_reports < <(
    comm -23 "${TEST_TMPDIR}/reports.before" "${TEST_TMPDIR}/reports.after"
)
mapfile -t new_reports < <(
    comm -13 "${TEST_TMPDIR}/reports.before" "${TEST_TMPDIR}/reports.after"
)
[[ "${#removed_reports[@]}" -eq 0 ]] ||
    die "un rapport préexistant a été supprimé."
[[ "${#new_reports[@]}" -eq 1 ]] ||
    die "impossible d'identifier un unique nouveau rapport."
new_report="${REPORT_DIR}/${new_reports[0]}"

grep -Fq 'Verdict                  : BLOCK' "$new_report" ||
    die "verdict BLOCK absent du rapport."
grep -Fq 'Code de sortie           : 29 (POLICY_BLOCK)' "$new_report" ||
    die "code POLICY_BLOCK absent du rapport."
grep -Fq '[BLOCK] L’utilisation de --overwrite est interdite par Smart Update.' \
    "$new_report" ||
    die "BLOCK déterministe overwrite_guard absent du rapport."
grep -Fq 'Result                 : DISABLED' "$new_report" ||
    die "la phase AUR n'est pas marquée DISABLED dans le rapport."
grep -Fq 'Installed: 0' "$new_report" ||
    die "le rapport indique une installation officielle."
verdict_block_confirmed="oui"

tail -n 50 "$new_report"
test_completed="yes"
