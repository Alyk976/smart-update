#!/usr/bin/env bash

require_root() {
    if ((EUID != 0)); then
        logger_die "Smart Update doit être exécuté avec les droits root."
    fi
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        logger_die "Commande requise absente : ${command_name}"
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

    if [[ "${CHECK_ARCH_NEWS:-no}" == "yes" ]]; then
        commands+=(xmllint)
    fi

    local command_name

    for command_name in "${commands[@]}"; do
        require_command "$command_name"
    done
}

check_network() {
    logger_info "Vérification de l’accès au dépôt Arch Linux."

    if ! curl \
        --fail \
        --silent \
        --show-error \
        --head \
        --max-time 15 \
        "https://geo.mirror.pkgbuild.com/" \
        >/dev/null; then

        logger_die "Le dépôt Arch Linux est inaccessible."
    fi
}

check_root_space() {
    local available_mib

    available_mib=$(
        df --output=avail -BM / \
            | awk 'NR == 2 {
                gsub(/M/, "", $1)
                print $1
            }'
    )

    if [[ ! "$available_mib" =~ ^[0-9]+$ ]]; then
        logger_die "Impossible de calculer l’espace disque disponible."
    fi

    logger_info "Espace disponible sur / : ${available_mib} Mio."

    if ((available_mib < MIN_ROOT_FREE_MIB)); then
        logger_blocked "Espace insuffisant : ${available_mib} Mio disponibles."
        exit 10
    fi
}

check_pacman_lock() {
    if [[ ! -e /var/lib/pacman/db.lck ]]; then
        return 0
    fi

    if pgrep -x pacman >/dev/null 2>&1 \
        || pgrep -x yay >/dev/null 2>&1 \
        || pgrep -x paru >/dev/null 2>&1; then

        logger_blocked "Un gestionnaire de paquets est déjà en cours d’exécution."
        exit 11
    fi

    logger_blocked "Le verrou /var/lib/pacman/db.lck existe sans processus Pacman actif."
    logger_blocked "Suppression automatique refusée. Vérification manuelle nécessaire."
    exit 12
}
