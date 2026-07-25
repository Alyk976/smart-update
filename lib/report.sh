#!/usr/bin/env bash

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
    } >"$REPORT_FILE"

    chmod 640 "$REPORT_FILE"
    logger_info "Rapport créé : ${REPORT_FILE}"
}

report_finalize() {
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
            local index

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
