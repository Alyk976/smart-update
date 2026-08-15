#!/usr/bin/env bash

REPORT_FINALIZED="no"

create_report() {
    local timestamp

    REPORT_FINALIZED="no"
    REPORT_START_EPOCH=$(date +%s)
    timestamp=$(date '+%Y%m%d-%H%M%S')
    REPORT_FILE="${REPORT_DIR}/report-${timestamp}.txt"

    {
        printf 'Smart Update %s\n' "$(smart_update_package_version)"
        echo "Date : $(date --iso-8601=seconds)"
        echo "Machine : $(cat /etc/hostname 2>/dev/null || echo inconnue)"
        echo "Noyau : $(uname -r)"
        echo
        echo "Paquets explicitement installés :"
        pacman -Qqe
        echo
        echo "Paquets Foreign installés (classification AUR ultérieure) :"
        pacman -Qm || true
    } >"$REPORT_FILE"

    chmod 640 "$REPORT_FILE"
    logger_info "Rapport créé : ${REPORT_FILE}"
}

report_finalize() {
    local exit_code="${1:-0}"
    local index
    local end_epoch
    local duration_seconds
    local duration_hours
    local duration_minutes
    local duration_remaining_seconds
    local foreign_package_count
    local exit_label
    local exit_description
    local aur_detected_count=0 aur_approved_count=0 aur_skipped_count=0
    local aur_unknown_count=0 aur_installed_count=0

    if [[ "${REPORT_FINALIZED:-no}" == "yes" ]]; then
        return 0
    fi

    if [[ -z "${REPORT_FILE:-}" || ! -f "$REPORT_FILE" ]]; then
        return 0
    fi

    end_epoch=$(date +%s)
    duration_seconds=$((end_epoch - REPORT_START_EPOCH))
    duration_hours=$((duration_seconds / 3600))
    duration_minutes=$(((duration_seconds % 3600) / 60))
    duration_remaining_seconds=$((duration_seconds % 60))
    foreign_package_count=$(pacman -Qmq 2>/dev/null | wc -l)
    exit_label=$(exit_code_label "$exit_code")
    exit_description=$(exit_code_description "$exit_code")
    declare -p AUR_UPDATE_NAMES >/dev/null 2>&1 \
        && aur_detected_count=${#AUR_UPDATE_NAMES[@]}
    declare -p AUR_APPROVED_PACKAGES >/dev/null 2>&1 \
        && aur_approved_count=${#AUR_APPROVED_PACKAGES[@]}
    declare -p AUR_SKIPPED_UNSTABLE >/dev/null 2>&1 \
        && aur_skipped_count=${#AUR_SKIPPED_UNSTABLE[@]}
    declare -p UNKNOWN_FOREIGN_PACKAGES >/dev/null 2>&1 \
        && aur_unknown_count=${#UNKNOWN_FOREIGN_PACKAGES[@]}
    declare -p AUR_INSTALLED_PACKAGES >/dev/null 2>&1 \
        && aur_installed_count=${#AUR_INSTALLED_PACKAGES[@]}

    {
        echo
        echo "===================================================="
        echo "Décision finale"
        echo "===================================================="
        echo
        echo "${DECISION_FINAL}"
        echo
        echo "Décisions enregistrées :"

        if ((${#DECISION_REASONS[@]} == 0)); then
            echo "Aucune décision enregistrée."
        else
            for index in "${!DECISION_REASONS[@]}"; do
                printf '[%s] %s\n' \
                    "${DECISION_TYPES[$index]}" \
                    "${DECISION_REASONS[$index]}"

                case "${DECISION_REASONS[$index]}" in
                    "Mises à jour critiques détectées :")
                        if ((${#CRITICAL_UPDATES[@]} > 0)); then
                            printf '    - %s\n' "${CRITICAL_UPDATES[@]}"
                        fi
                        ;;
                    *"nouveau(x) paquet(s) ou nouvelle(s) dépendance(s) détecté(s).")
                        if ((${#NEW_PACKAGES[@]} > 0)); then
                            printf '    - %s\n' "${NEW_PACKAGES[@]}"
                        fi
                        ;;
                esac
            done
        fi

        echo
        echo "===================================================="
        echo "Official updates"
        echo "===================================================="
        printf 'Detected : %d\n' "${#UPDATE_PACKAGES[@]}"
        printf 'Installed: %d\n' "${OFFICIAL_INSTALLED_COUNT:-0}"
        if [[ "${MODE:-audit}" == "audit" ]]; then
            printf 'Skipped  : %d (audit mode)\n' "${#UPDATE_PACKAGES[@]}"
        else
            printf 'Skipped  : 0\n'
        fi
        printf 'Result   : %s\n' "${OFFICIAL_RESULT:-NOT_RUN}"

        echo
        echo "===================================================="
        echo "AUR updates"
        echo "===================================================="
        printf 'Detected              : %d\n' "$aur_detected_count"
        printf 'Stable approved        : %d\n' "$aur_approved_count"
        printf 'Unstable skipped       : %d\n' "$aur_skipped_count"
        printf 'Unknown foreign        : %d\n' "$aur_unknown_count"
        printf 'Installed              : %d\n' "$aur_installed_count"
        if [[ "${AUR_RESULT:-}" == "FAILED" ]]; then
            printf 'Failed                 : %s\n' "${AUR_PHASE_ERROR:-unknown error}"
        else
            printf 'Failed                 : 0\n'
        fi
        if [[ "${AUR_RESULT:-}" == "DEFERRED_HELPER_INCOMPATIBLE" ]]; then
            printf 'Deferred               : %s\n' "${AUR_PHASE_ERROR:-unknown reason}"
        fi
        printf 'Result                 : %s\n' "${AUR_RESULT:-NOT_AVAILABLE}"
        printf 'Helper recheck required: %s\n' "${AUR_HELPER_RECHECK_REQUIRED:-no}"
        printf 'Helper post-update     : %s\n' "${AUR_HELPER_POST_UPDATE_STATUS:-NOT_CHECKED}"
        if [[ -n "${AUR_PHASE_ERROR:-}" ]]; then
            printf 'Detail                 : %s\n' "$AUR_PHASE_ERROR"
        fi
        if ((aur_skipped_count > 0)); then
            printf 'SKIPPED_UNSTABLE       : %s\n' "${AUR_SKIPPED_UNSTABLE[@]}"
        fi
        if ((aur_unknown_count > 0)); then
            printf 'SKIPPED_UNKNOWN_SOURCE : %s\n' "${UNKNOWN_FOREIGN_PACKAGES[@]}"
        fi

        echo
        echo "===================================================="
        echo "Résumé"
        echo "===================================================="
        echo
        printf 'Paquets à mettre à jour : %d\n' "${#UPDATE_PACKAGES[@]}"
        printf 'Paquets critiques       : %d\n' "${#CRITICAL_UPDATES[@]}"
        printf 'Nouvelles dépendances   : %d\n' "${#NEW_PACKAGES[@]}"
        printf 'Paquets étrangers/AUR   : %d\n' "$foreign_package_count"
        printf 'Verdict                  : %s\n' "$DECISION_FINAL"
        printf 'Code de sortie           : %d (%s)\n' "$exit_code" "$exit_label"
        printf 'Statut                    : %s\n' "$exit_description"
        printf 'Durée                    : %02d:%02d:%02d\n' \
            "$duration_hours" \
            "$duration_minutes" \
            "$duration_remaining_seconds"

        echo
        echo "Fin du rapport : $(date --iso-8601=seconds)"
    } >>"$REPORT_FILE"

    REPORT_FINALIZED="yes"
    logger_info "Rapport finalisé : ${REPORT_FILE}"
}

cleanup_old_reports() {
    find "$REPORT_DIR" \
        -type f \
        -name 'report-*.txt' \
        -mtime "+${REPORT_RETENTION_DAYS}" \
        -delete
}
