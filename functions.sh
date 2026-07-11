#!/usr/bin/env bash

log() {
    local level="$1"
    shift

    printf '[%s] [%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$level" \
        "$*" |
        tee -a "$LOG_FILE"
}

info() {
    log "INFO" "$@"
}

warning() {
    log "WARNING" "$@"
}

error() {
    log "ERROR" "$@"
}

blocked() {
    local reason="$*"

    log "BLOCKED" "$reason"
    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$reason" >> "$BLOCKED_LOG"
}

die() {
    error "$*"
    exit 1
}

require_root() {
    if (( EUID != 0 )); then
        die "Smart Update doit être exécuté avec les droits root."
    fi
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        die "Commande requise absente : ${command_name}"
    fi
}

check_required_commands() {
    local commands=(
        pacman
        checkupdates
        curl
        awk
        grep
        sed
        sort
        comm
        df
        flock
    )

    local command_name

    for command_name in "${commands[@]}"; do
        require_command "$command_name"
    done
}

check_network() {
    info "Vérification de l’accès au dépôt Arch Linux."

    if ! curl \
        --fail \
        --silent \
        --show-error \
        --head \
        --max-time 15 \
        "https://geo.mirror.pkgbuild.com/" \
        >/dev/null; then

        die "Le dépôt Arch Linux est inaccessible."
    fi
}

check_root_space() {
    local available_mib

    available_mib=$(
        df --output=avail -BM / |
            awk 'NR == 2 {
                gsub(/M/, "", $1)
                print $1
            }'
    )

    if [[ ! "$available_mib" =~ ^[0-9]+$ ]]; then
        die "Impossible de calculer l’espace disque disponible."
    fi

    info "Espace disponible sur / : ${available_mib} Mio."

    if (( available_mib < MIN_ROOT_FREE_MIB )); then
        blocked "Espace insuffisant : ${available_mib} Mio disponibles."
        exit 10
    fi
}

check_pacman_lock() {
    if [[ ! -e /var/lib/pacman/db.lck ]]; then
        return 0
    fi

    if pgrep -x pacman >/dev/null 2>&1 ||
       pgrep -x yay >/dev/null 2>&1 ||
       pgrep -x paru >/dev/null 2>&1; then

        blocked "Un gestionnaire de paquets est déjà en cours d’exécution."
        exit 11
    fi

    blocked "Le verrou /var/lib/pacman/db.lck existe sans processus Pacman actif."
    blocked "Suppression automatique refusée. Vérification manuelle nécessaire."
    exit 12
}

create_report() {
    local timestamp

    timestamp=$(date '+%Y%m%d-%H%M%S')
    REPORT_FILE="${REPORT_DIR}/report-${timestamp}.txt"

    {
        echo "Smart Update v2"
        echo "Date : $(date --iso-8601=seconds)"
        echo "Machine : $(cat /etc/hostname 2>/dev/null || echo inconnue)"
        echo "Noyau : $(uname -r)"
        echo
        echo "Paquets explicitement installés :"
        pacman -Qqe
        echo
        echo "Paquets étrangers/AUR :"
        pacman -Qm || true
    } > "$REPORT_FILE"

    chmod 640 "$REPORT_FILE"
    info "Rapport créé : ${REPORT_FILE}"
}

cleanup_old_reports() {
    find "$REPORT_DIR" \
        -type f \
        -name 'report-*.txt' \
        -mtime "+${REPORT_RETENTION_DAYS}" \
        -delete
}
