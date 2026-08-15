#!/usr/bin/env bash
# shellcheck disable=SC2034

# Codes de sortie publics de Smart Update.
# Ces constantes sont consommées par les modules qui sourcent ce fichier ;
# ShellCheck ne suit pas ces usages inter-fichiers.
readonly EXIT_OK=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_LOW_DISK_SPACE=10
readonly EXIT_PACKAGE_MANAGER_ACTIVE=11
readonly EXIT_STALE_PACMAN_LOCK=12
readonly EXIT_INSTANCE_ALREADY_RUNNING=20
readonly EXIT_CHECKUPDATES_FAILED=21
readonly EXIT_PACMAN_TRANSACTION_FAILED=26
readonly EXIT_INVALID_MODE=28
readonly EXIT_POLICY_BLOCK=29
readonly EXIT_INVALID_FINAL_DECISION=30
readonly EXIT_AUR_DISCOVERY_FAILED=31
readonly EXIT_AUR_UPDATE_FAILED=32

exit_code_label() {
    case "${1:-}" in
        0)  printf '%s\n' 'OK' ;;
        1)  printf '%s\n' 'GENERAL_ERROR' ;;
        10) printf '%s\n' 'LOW_DISK_SPACE' ;;
        11) printf '%s\n' 'PACKAGE_MANAGER_ACTIVE' ;;
        12) printf '%s\n' 'STALE_PACMAN_LOCK' ;;
        20) printf '%s\n' 'INSTANCE_ALREADY_RUNNING' ;;
        21) printf '%s\n' 'CHECKUPDATES_FAILED' ;;
        26) printf '%s\n' 'PACMAN_TRANSACTION_FAILED' ;;
        28) printf '%s\n' 'INVALID_MODE' ;;
        29) printf '%s\n' 'POLICY_BLOCK' ;;
        30) printf '%s\n' 'INVALID_FINAL_DECISION' ;;
        31) printf '%s\n' 'AUR_DISCOVERY_FAILED' ;;
        32) printf '%s\n' 'AUR_UPDATE_FAILED' ;;
        *)  printf '%s\n' 'UNKNOWN' ;;
    esac
}

exit_code_description() {
    case "${1:-}" in
        0)  printf '%s\n' 'Exécution terminée normalement.' ;;
        1)  printf '%s\n' 'Erreur générale.' ;;
        10) printf '%s\n' 'Espace disque insuffisant.' ;;
        11) printf '%s\n' 'Un gestionnaire de paquets est déjà actif.' ;;
        12) printf '%s\n' 'Verrou Pacman orphelin détecté.' ;;
        20) printf '%s\n' 'Une autre instance de Smart Update est active.' ;;
        21) printf '%s\n' 'Échec de la détection des mises à jour.' ;;
        26) printf '%s\n' 'Échec de la transaction Pacman.' ;;
        28) printf '%s\n' 'Mode de fonctionnement invalide.' ;;
        29) printf '%s\n' 'Installation bloquée volontairement par les politiques de sécurité.' ;;
        30) printf '%s\n' 'Décision finale invalide.' ;;
        31) printf '%s\n' 'Échec de la découverte ou validation AUR.' ;;
        32) printf '%s\n' 'La phase officielle a réussi mais la mise à jour AUR a échoué.' ;;
        *)  printf '%s\n' 'Code de sortie inconnu.' ;;
    esac
}
