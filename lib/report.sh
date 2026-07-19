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
    } > "$REPORT_FILE"

    chmod 640 "$REPORT_FILE"
    logger_info "Rapport créé : ${REPORT_FILE}"
}

cleanup_old_reports() {
    find "$REPORT_DIR" \
        -type f \
        -name 'report-*.txt' \
        -mtime "+${REPORT_RETENTION_DAYS}" \
        -delete
}
