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
readonly ARCH_NEWS_STATE_FILE="/var/lib/smart-update/arch-news.last"
readonly LAST_SUCCESS_FILE="/var/lib/smart-update/last-success"
readonly SMART_UPDATE_BIN="/usr/bin/smart-update"
readonly REAL_PACMAN="/usr/bin/pacman"
readonly TIMER_UNIT="smart-update.timer"
readonly SERVICE_UNIT="smart-update.service"

TEST_TMPDIR=$(mktemp -d /tmp/smart-update-audit.XXXXXXXX)
GUARD_TMPDIR=$(mktemp -d /tmp/smart-update-audit-guards.XXXXXXXX)
readonly TEST_TMPDIR GUARD_TMPDIR
readonly CONFIG_BACKUP="${TEST_TMPDIR}/smart-update.conf.original"
readonly ARCH_NEWS_BACKUP="${TEST_TMPDIR}/arch-news.last.original"
readonly LAST_SUCCESS_BACKUP="${TEST_TMPDIR}/last-success.original"
readonly PACMAN_TRACE="${GUARD_TMPDIR}/pacman.trace"
readonly YAY_TRACE="${GUARD_TMPDIR}/yay.trace"

backup_ready="no"
config_restored_identical="non vérifié"
timer_state_recorded="no"
timer_stop_attempted="no"
test_completed="no"
integrity_before_checked="no"
packages_before_ready="no"
arch_news_snapshot_ready="no"
arch_news_initial_exists="no"
arch_news_initial_sha=""
arch_news_initial_metadata=""
arch_news_restored="non vérifié"
last_success_snapshot_ready="no"
last_success_initial_exists="no"
last_success_initial_sha=""
last_success_initial_metadata=""
last_success_unchanged="non vérifié"
smart_update_version="inconnue"
audit_rc="non exécuté"
package_count_before="inconnu"
package_count_after="inconnu"
packages_unchanged="non vérifié"
new_report="aucun"
report_result="non vérifié"
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
            printf 'ERREUR CRITIQUE : restauration automatique impossible pour l’état enabled %s.\n' \
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

restore_arch_news_state() {
    local restored_sha restored_metadata

    [[ "$arch_news_snapshot_ready" == "yes" ]] || return 0

    if [[ "$arch_news_initial_exists" == "yes" ]]; then
        cp -a -- "$ARCH_NEWS_BACKUP" "$ARCH_NEWS_STATE_FILE" || return 1
        restored_sha=$(sha256sum "$ARCH_NEWS_STATE_FILE" | awk '{print $1}')
        restored_metadata=$(stat -c '%a|%u|%g|%s|%y' "$ARCH_NEWS_STATE_FILE")
        [[ "$restored_sha" == "$arch_news_initial_sha" \
            && "$restored_metadata" == "$arch_news_initial_metadata" ]] ||
            return 1
    else
        rm -f -- "$ARCH_NEWS_STATE_FILE" || return 1
        [[ ! -e "$ARCH_NEWS_STATE_FILE" ]] || return 1
    fi

    arch_news_restored="oui"
}

restore_last_success_state() {
    local current_sha="" current_metadata=""
    local state_changed="no"
    local restored_sha restored_metadata

    [[ "$last_success_snapshot_ready" == "yes" ]] || return 0

    if [[ "$last_success_initial_exists" == "yes" ]]; then
        if [[ ! -f "$LAST_SUCCESS_FILE" ]]; then
            state_changed="yes"
        else
            current_sha=$(sha256sum "$LAST_SUCCESS_FILE" | awk '{print $1}')
            current_metadata=$(stat -c '%a|%u|%g|%s|%y' "$LAST_SUCCESS_FILE")
            if [[ "$current_sha" != "$last_success_initial_sha" \
                || "$current_metadata" != "$last_success_initial_metadata" ]]; then
                state_changed="yes"
            fi
        fi

        if [[ "$state_changed" == "no" ]]; then
            last_success_unchanged="oui"
            return 0
        fi

        cp -a -- "$LAST_SUCCESS_BACKUP" "$LAST_SUCCESS_FILE" || return 1
        restored_sha=$(sha256sum "$LAST_SUCCESS_FILE" | awk '{print $1}')
        restored_metadata=$(stat -c '%a|%u|%g|%s|%y' "$LAST_SUCCESS_FILE")
        [[ "$restored_sha" == "$last_success_initial_sha" \
            && "$restored_metadata" == "$last_success_initial_metadata" ]] ||
            return 1
    else
        if [[ ! -e "$LAST_SUCCESS_FILE" ]]; then
            last_success_unchanged="oui"
            return 0
        fi
        state_changed="yes"
        rm -f -- "$LAST_SUCCESS_FILE" || return 1
        [[ ! -e "$LAST_SUCCESS_FILE" ]] || return 1
    fi

    last_success_unchanged="non"
    return 2
}

cleanup() {
    local original_status=$?
    local cleanup_status=0
    local restored_sha="" restored_metadata=""
    local state_status=0

    trap - EXIT INT TERM HUP
    set +e

    if [[ "$backup_ready" == "yes" ]]; then
        if [[ -f "$CONFIG_FILE" ]]; then
            restored_sha=$(sha256sum "$CONFIG_FILE" | awk '{print $1}')
            restored_metadata=$(stat -c '%a|%u|%g|%s|%y' "$CONFIG_FILE")
        fi

        if [[ "$restored_sha" == "$original_config_sha" \
            && "$restored_metadata" == "$original_config_metadata" ]]; then
            config_restored_identical="oui"
        else
            printf '%s\n' \
                'ERREUR CRITIQUE : la configuration a changé pendant le test audit.' >&2
            cleanup_status=1
            if cp -a -- "$CONFIG_BACKUP" "$CONFIG_FILE"; then
                restored_sha=$(sha256sum "$CONFIG_FILE" | awk '{print $1}')
                restored_metadata=$(stat -c '%a|%u|%g|%s|%y' "$CONFIG_FILE")
                if [[ "$restored_sha" == "$original_config_sha" \
                    && "$restored_metadata" == "$original_config_metadata" ]]; then
                    config_restored_identical="oui"
                else
                    config_restored_identical="non"
                fi
            else
                config_restored_identical="non"
                printf '%s\n' \
                    'ERREUR CRITIQUE : restauration de la configuration impossible.' >&2
            fi
        fi
    fi

    if ! restore_arch_news_state; then
        arch_news_restored="non"
        printf '%s\n' \
            'ERREUR CRITIQUE : restauration de l’état Arch News impossible.' >&2
        cleanup_status=1
    fi

    restore_last_success_state
    state_status=$?
    case "$state_status" in
        0)
            ;;
        2)
            printf '%s\n' \
                'ERREUR CRITIQUE : last-success a été modifié en mode audit.' >&2
            cleanup_status=1
            ;;
        *)
            last_success_unchanged="non vérifiable"
            printf '%s\n' \
                'ERREUR CRITIQUE : restauration de last-success impossible.' >&2
            cleanup_status=1
            ;;
    esac

    # Le snapshot final précède la remise en route du timer, afin d’isoler le
    # scénario audit de toute exécution normale ultérieure.
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
                'ERREUR CRITIQUE : pacman -Qkk smart-update a échoué après le test.' >&2
            cleanup_status=1
        fi
    fi

    if [[ "$timer_state_recorded" == "yes" ]]; then
        if [[ "$timer_stop_attempted" == "yes" ]]; then
            if [[ "$config_restored_identical" != "oui" ]]; then
                printf '%s\n' \
                    'ERREUR CRITIQUE : timer laissé arrêté car la configuration n’est pas restaurée.' >&2
                cleanup_status=1
            else
                restore_timer_enabled_state || cleanup_status=1
                restore_timer_active_state || cleanup_status=1
            fi
        fi

        timer_enabled_final=$(timer_enabled_state)
        timer_active_final=$(timer_active_state)
        [[ "$timer_enabled_final" == "$timer_enabled_initial" ]] || {
            printf '%s\n' \
                'ERREUR CRITIQUE : état enabled du timer non restauré.' >&2
            cleanup_status=1
        }
        [[ "$timer_active_final" == "$timer_active_initial" ]] || {
            printf '%s\n' \
                'ERREUR CRITIQUE : état active du timer non restauré.' >&2
            cleanup_status=1
        }
    fi

    if [[ -d "$GUARD_TMPDIR" ]]; then
        cp -a -- "$PACMAN_TRACE" "${TEST_TMPDIR}/pacman.trace" 2>/dev/null || true
        cp -a -- "$YAY_TRACE" "${TEST_TMPDIR}/yay.trace" 2>/dev/null || true
        if [[ "$GUARD_TMPDIR" == /tmp/smart-update-audit-guards.* ]]; then
            rm -rf -- "$GUARD_TMPDIR"
        else
            printf 'ERREUR CRITIQUE : répertoire de guards invalide : %s\n' \
                "$GUARD_TMPDIR" >&2
            cleanup_status=1
        fi
    fi

    printf '\n====================================================\n'
    printf '%s\n' ' Résumé du test audit réel 1.1.0'
    printf '====================================================\n'
    printf 'Version Smart Update              : %s\n' "$smart_update_version"
    printf 'RC du test audit                  : %s\n' "$audit_rc"
    printf 'Rapport audit validé              : %s\n' "$report_result"
    printf 'Nombre de paquets avant           : %s\n' "$package_count_before"
    printf 'Nombre de paquets après           : %s\n' "$package_count_after"
    printf 'Aucun paquet modifié              : %s\n' "$packages_unchanged"
    printf 'Rapport généré                    : %s\n' "$new_report"
    printf 'Configuration restaurée identique : %s\n' \
        "$config_restored_identical"
    printf 'État Arch News restauré           : %s\n' "$arch_news_restored"
    printf 'last-success inchangé             : %s\n' "$last_success_unchanged"
    printf 'Timer enabled initial/final       : %s / %s\n' \
        "$timer_enabled_initial" "$timer_enabled_final"
    printf 'Timer active initial/final        : %s / %s\n' \
        "$timer_active_initial" "$timer_active_final"

    if ((cleanup_status == 0 && original_status == 0)) \
        && [[ "$test_completed" == "yes" ]]; then
        if [[ "$TEST_TMPDIR" == /tmp/smart-update-audit.* \
            && -d "$TEST_TMPDIR" ]]; then
            rm -rf -- "$TEST_TMPDIR"
        else
            printf 'ERREUR CRITIQUE : répertoire temporaire invalide : %s\n' \
                "$TEST_TMPDIR" >&2
            cleanup_status=1
        fi
    else
        printf 'Artefacts de diagnostic conservés dans : %s\n' \
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

    printf '%s\n' 'TEST RÉUSSI : mode audit sans modification de paquet.'
    exit 0
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

create_command_guards() {
    chmod 0755 "$GUARD_TMPDIR"
    : >"$PACMAN_TRACE"
    : >"$YAY_TRACE"
    chmod 0666 "$PACMAN_TRACE" "$YAY_TRACE"

    cat >"${GUARD_TMPDIR}/pacman" <<'PACMAN_GUARD'
#!/usr/bin/env bash
set -Eeuo pipefail

GUARD_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
readonly GUARD_DIR
readonly TRACE_FILE="${GUARD_DIR}/pacman.trace"
readonly SAFE_DB="/tmp/checkup-db-0/"

record() {
    local verdict="${1:?}"
    shift
    {
        printf '%s|pacman' "$verdict"
        printf '|%q' "$@"
        printf '\n'
    } >>"$TRACE_FILE"
}

allow() {
    record ALLOW "$@"
    exec /usr/bin/pacman "$@"
}

deny() {
    record DENY "$@"
    printf '%s\n' 'pacman guard: commande interdite en test audit.' >&2
    exit 125
}

case "${1:-}" in
    -Q)
        if (($# == 1)) \
            || (($# == 2)) && [[ "$2" == "smart-update" ]]; then
            allow "$@"
        fi
        ;;
    -Qq | -Qqe | -Qm | -Qmq | -Qqm)
        (($# == 1)) && allow "$@"
        ;;
    -S)
        if (($# == 7)) \
            && [[ "$2" == "--help" \
                && "$3" == "-y" \
                && "$4" == "-u" \
                && "$5" == "--config" \
                && "$6" == "/etc/pacman.conf" \
                && "$7" == "--" ]]; then
            allow "$@"
        fi
        ;;
    -Sy)
        if (($# == 6)) \
            && [[ "$2" == "--disable-sandbox-filesystem" \
                && "$3" == "--dbpath" \
                && "$4" == "$SAFE_DB" \
                && "$5" == "--logfile" \
                && "$6" == "/dev/null" ]]; then
            allow "$@"
        fi
        ;;
    -Qu)
        if (($# == 3)) \
            && [[ "$2" == "--dbpath" && "$3" == "$SAFE_DB" ]]; then
            allow "$@"
        fi
        if (($# == 5)) \
            && [[ "$2" == "--dbpath" \
                && "$3" == "$SAFE_DB" \
                && "$4" == "--color" \
                && "$5" == "always" ]]; then
            allow "$@"
        fi
        ;;
esac

deny "$@"
PACMAN_GUARD

    cat >"${GUARD_TMPDIR}/yay" <<'YAY_GUARD'
#!/usr/bin/env bash
set -Eeuo pipefail

GUARD_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
readonly GUARD_DIR
readonly TRACE_FILE="${GUARD_DIR}/yay.trace"

record() {
    local verdict="${1:?}"
    shift
    {
        printf '%s|yay' "$verdict"
        printf '|%q' "$@"
        printf '\n'
    } >>"$TRACE_FILE"
}

allow() {
    record ALLOW "$@"
    [[ -x /usr/bin/yay ]] || exit 127
    PATH="${GUARD_DIR}:/usr/local/bin:/usr/bin:/bin" \
        exec /usr/bin/yay "$@"
}

deny() {
    record DENY "$@"
    printf '%s\n' 'yay guard: commande interdite en test audit.' >&2
    exit 125
}

case "${1:-}" in
    --version | --help)
        (($# == 1)) && allow "$@"
        ;;
    -Qua)
        if (($# == 4)) \
            && [[ "$2" == "--aur" \
                && "$3" == "--color" \
                && "$4" == "never" ]]; then
            allow "$@"
        fi
        ;;
    -Si)
        if (($# == 5)) \
            && [[ "$2" == "--aur" \
                && "$3" == "--color" \
                && "$4" == "never" \
                && "$5" =~ ^[[:alnum:]@._+:-]+$ ]]; then
            allow "$@"
        fi
        ;;
esac

deny "$@"
YAY_GUARD

    chmod 0755 "${GUARD_TMPDIR}/pacman" "${GUARD_TMPDIR}/yay"
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
package_version=${smart_update_query#smart-update }

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
config_values=$(bash -c '
    set -Eeuo pipefail
    source "$1"
    config_load "$2"
    printf "%s|%s|%s|%s|%s\n" \
        "$MODE" "$ENABLE_AUR_UPDATES" "$AUR_HELPER" "$AUR_USER" \
        "$REPORT_RETENTION_DAYS"
' _ "$CONFIG_MODULE" "$CONFIG_FILE") ||
    die "configuration réelle refusée par Smart Update 1.1.0."
IFS='|' read -r current_mode current_aur current_helper current_aur_user \
    report_retention_days <<<"$config_values"
[[ "$current_mode" == "audit" ]] ||
    die "MODE réel attendu audit, obtenu : ${current_mode}"
[[ "$current_aur" == "yes" ]] ||
    die "ENABLE_AUR_UPDATES réel attendu yes, obtenu : ${current_aur}"
[[ "$current_helper" == "yay" ]] ||
    die "AUR_HELPER réel inattendu : ${current_helper}"
[[ -n "$current_aur_user" ]] || die "AUR_USER réel absent."
[[ "$report_retention_days" =~ ^[0-9]+$ \
    && "$report_retention_days" -gt 0 ]] ||
    die "REPORT_RETENTION_DAYS invalide : ${report_retention_days}"

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

if [[ -e "$ARCH_NEWS_STATE_FILE" ]]; then
    [[ -f "$ARCH_NEWS_STATE_FILE" ]] ||
        die "état Arch News non régulier : ${ARCH_NEWS_STATE_FILE}"
    cp -a -- "$ARCH_NEWS_STATE_FILE" "$ARCH_NEWS_BACKUP"
    arch_news_initial_exists="yes"
    arch_news_initial_sha=$(sha256sum "$ARCH_NEWS_STATE_FILE" | awk '{print $1}')
    arch_news_initial_metadata=$(stat -c '%a|%u|%g|%s|%y' "$ARCH_NEWS_STATE_FILE")
fi
arch_news_snapshot_ready="yes"

if [[ -e "$LAST_SUCCESS_FILE" ]]; then
    [[ -f "$LAST_SUCCESS_FILE" ]] ||
        die "last-success non régulier : ${LAST_SUCCESS_FILE}"
    cp -a -- "$LAST_SUCCESS_FILE" "$LAST_SUCCESS_BACKUP"
    last_success_initial_exists="yes"
    last_success_initial_sha=$(sha256sum "$LAST_SUCCESS_FILE" | awk '{print $1}')
    last_success_initial_metadata=$(stat -c '%a|%u|%g|%s|%y' "$LAST_SUCCESS_FILE")
fi
last_success_snapshot_ready="yes"

"$REAL_PACMAN" -Qkk smart-update ||
    die "pacman -Qkk smart-update a échoué avant le scénario."
integrity_before_checked="yes"

LC_ALL=C "$REAL_PACMAN" -Q | LC_ALL=C sort \
    >"${TEST_TMPDIR}/packages.before"
packages_before_ready="yes"
package_count_before=$(wc -l <"${TEST_TMPDIR}/packages.before")

[[ -d "$REPORT_DIR" ]] || die "répertoire des rapports absent."
retention_guard=$((report_retention_days - 1))
if find "$REPORT_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'report-*.txt' \
    -mtime "+${retention_guard}" \
    -print -quit |
    grep -q .; then
    die "un rapport approche ou dépasse la rétention ; exécution refusée pour éviter sa suppression."
fi

report_count_before=$(count_reports)
find "$REPORT_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'report-*.txt' \
    -printf '%f\n' |
    LC_ALL=C sort >"${TEST_TMPDIR}/reports.before"

create_command_guards

printf '%s\n' '--- Exécution réelle du mode audit protégé ---'
set +e
PATH="${GUARD_TMPDIR}:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin" \
    "$SMART_UPDATE_BIN"
audit_rc=$?
set -e

cp -a -- "$PACMAN_TRACE" "${TEST_TMPDIR}/pacman.trace"
cp -a -- "$YAY_TRACE" "${TEST_TMPDIR}/yay.trace"

if grep -Fq 'DENY|' "$PACMAN_TRACE"; then
    sed -n '1,80p' "$PACMAN_TRACE" >&2
    die "Smart Update a tenté un appel pacman interdit."
fi
if grep -Fq 'DENY|' "$YAY_TRACE"; then
    sed -n '1,80p' "$YAY_TRACE" >&2
    die "Smart Update a tenté un appel yay interdit."
fi
grep -Fq 'ALLOW|pacman|-Sy|--disable-sandbox-filesystem|--dbpath|/tmp/checkup-db-0/|--logfile|/dev/null' \
    "$PACMAN_TRACE" ||
    die "synchronisation checkupdates isolée absente de la trace pacman."
grep -Fq 'ALLOW|pacman|-Qu|--dbpath|/tmp/checkup-db-0/' \
    "$PACMAN_TRACE" ||
    die "lecture checkupdates absente de la trace pacman."
grep -Fq 'ALLOW|pacman|-Qq' "$PACMAN_TRACE" ||
    die "lecture des paquets installés absente de la trace pacman."

case "$audit_rc" in
    0 | 29 | 31 | 34)
        ;;
    *)
        die "code retour audit inattendu : ${audit_rc}."
        ;;
esac

printf '%s\n' '--- Vérification du rapport audit ---'
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

awk '/^Official updates$/{capture=1; next} /^AUR updates$/{capture=0} capture' \
    "$new_report" >"${TEST_TMPDIR}/official.section"
awk '/^AUR updates$/{capture=1; next} /^Résumé$/{capture=0} capture' \
    "$new_report" >"${TEST_TMPDIR}/aur.section"

grep -Fqx "Smart Update v${package_version}" "$new_report" ||
    die "version 1.1.0.dev du rapport incorrecte."
grep -Eq '^Detected : [0-9]+$' "${TEST_TMPDIR}/official.section" ||
    die "compteur officiel absent du rapport."
grep -Fqx 'Installed: 0' "${TEST_TMPDIR}/official.section" ||
    die "le rapport indique une installation officielle."
grep -Eq '^Skipped  : [0-9]+ \(audit mode\)$' \
    "${TEST_TMPDIR}/official.section" ||
    die "marqueur audit absent du résultat officiel."
grep -Eq '^Detected[[:space:]]*: [0-9]+$' "${TEST_TMPDIR}/aur.section" ||
    die "compteur AUR absent du rapport."
grep -Eq '^Stable approved[[:space:]]*: [0-9]+$' \
    "${TEST_TMPDIR}/aur.section" ||
    die "compteur AUR stable absent du rapport."
grep -Eq '^Unstable skipped[[:space:]]*: [0-9]+$' \
    "${TEST_TMPDIR}/aur.section" ||
    die "compteur AUR instable absent du rapport."
grep -Fqx 'Installed              : 0' "${TEST_TMPDIR}/aur.section" ||
    die "le rapport indique une installation AUR."
grep -Fqx 'Helper post-update     : NOT_CHECKED' \
    "${TEST_TMPDIR}/aur.section" ||
    die "le helper AUR a été revalidé après une prétendue transaction."

official_result=$(sed -n \
    's/^Result[[:space:]]*:[[:space:]]*//p' \
    "${TEST_TMPDIR}/official.section")
aur_result=$(sed -n \
    's/^Result[[:space:]]*:[[:space:]]*//p' \
    "${TEST_TMPDIR}/aur.section")
verdict=$(sed -n \
    's/^Verdict[[:space:]]*:[[:space:]]*//p' \
    "$new_report")

case "$audit_rc" in
    0)
        [[ "$official_result" == "ANALYZED" ]] ||
            die "résultat officiel inattendu pour RC=0 : ${official_result}"
        [[ "$aur_result" == "ANALYZED" \
            || "$aur_result" == "NOT_AVAILABLE" ]] ||
            die "résultat AUR inattendu pour RC=0 : ${aur_result}"
        [[ "$verdict" == "ALLOW" || "$verdict" == "WARNING" ]] ||
            die "verdict inattendu pour RC=0 : ${verdict}"
        expected_label="OK"
        ;;
    29)
        [[ "$official_result" == "NOT_RUN" ]] ||
            die "résultat officiel inattendu pour RC=29 : ${official_result}"
        [[ "$verdict" == "BLOCK" ]] ||
            die "verdict inattendu pour RC=29 : ${verdict}"
        case "$aur_result" in
            ANALYZED | NOT_AVAILABLE | FAILED)
                ;;
            *)
                die "résultat AUR inattendu pour RC=29 : ${aur_result}"
                ;;
        esac
        expected_label="POLICY_BLOCK"
        ;;
    31)
        [[ "$official_result" == "ANALYZED" ]] ||
            die "résultat officiel inattendu pour RC=31 : ${official_result}"
        [[ "$aur_result" == "FAILED" ]] ||
            die "résultat AUR inattendu pour RC=31 : ${aur_result}"
        expected_label="AUR_DISCOVERY_FAILED"
        ;;
    34)
        [[ "$official_result" == "MANUAL_TRANSACTION_REQUIRED" ]] ||
            die "résultat officiel inattendu pour RC=34 : ${official_result}"
        [[ "$aur_result" == "DEFERRED_OFFICIAL_UPDATE_REQUIRED" ]] ||
            die "résultat AUR inattendu pour RC=34 : ${aur_result}"
        expected_label="MANUAL_TRANSACTION_REQUIRED"
        ;;
esac

grep -Fq "Code de sortie           : ${audit_rc} (${expected_label})" \
    "$new_report" ||
    die "code de sortie ou libellé absent du rapport."

report_result="oui (${official_result}/${aur_result})"
tail -n 60 "$new_report"
test_completed="yes"
