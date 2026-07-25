#!/usr/bin/env bash

create_report() {
    local timestamp

    REPORT_START_EPOCH=$(date +%s)
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
    } >"$REPORT_FILE"

    chmod 640 "$REPORT_FILE"
    logger_info "Rapport créé : ${REPORT_FILE}"
}

report_finalize() {
    local index
    local end_epoch
    local duration_seconds
    local duration_hours
    local duration_minutes
    local duration_remaining_seconds
    local foreign_package_count

    end_epoch=$(date +%s)
    duration_seconds=$((end_epoch - REPORT_START_EPOCH))
    duration_hours=$((duration_seconds / 3600))
    duration_minutes=$(((duration_seconds % 3600) / 60))
    duration_remaining_seconds=$((duration_seconds % 60))
    foreign_package_count=$(pacman -Qmq 2>/dev/null | wc -l)

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
                    "Nouveaux paquets ou nouvelles dépendances détectés :")
                        if ((${#NEW_PACKAGES[@]} > 0)); then
                            printf '    - %s\n' "${NEW_PACKAGES[@]}"
                        fi
                        ;;
                esac
            done
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
        printf 'Durée                    : %02d:%02d:%02d\n' \
            "$duration_hours" \
            "$duration_minutes" \
            "$duration_remaining_seconds"

        echo
        echo "Fin du rapport : $(date --iso-8601=seconds)"
    } >>"$REPORT_FILE"

    logger_info "Rapport finalisé : ${REPORT_FILE}"
}

cleanup_old_reports() {
    find "$REPORT_DIR" \
        -type f \
        -name 'report-*.txt' \
        -mtime "+${REPORT_RETENTION_DAYS}" \
        -delete
}
