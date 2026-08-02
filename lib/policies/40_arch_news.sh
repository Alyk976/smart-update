#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="arch_news"
    POLICY_DETAILS=()

    case "${ARCH_NEWS_CONTEXT_STATUS:-}" in
        DISABLED)
            POLICY_RESULT="ALLOW"
            POLICY_REASON="Consultation des annonces Arch Linux désactivée."
            return
            ;;

        UP_TO_DATE)
            POLICY_RESULT="ALLOW"
            POLICY_REASON="Aucune nouvelle annonce Arch Linux."
            return
            ;;

        ERROR)
            POLICY_RESULT="BLOCK"
            POLICY_REASON="${ARCH_NEWS_CONTEXT_ERROR:-Erreur Arch News inconnue.}"
            return
            ;;

        NEW)
            ;;

        "")
            POLICY_RESULT="BLOCK"
            POLICY_REASON="Contexte Arch News non préparé."
            return
            ;;

        *)
            POLICY_RESULT="BLOCK"
            POLICY_REASON="État Arch News invalide : ${ARCH_NEWS_CONTEXT_STATUS}."
            return
            ;;
    esac

    if ! declare -p \
        ARCH_NEWS_NEW_INDEXES \
        ARCH_NEWS_TITLES \
        ARCH_NEWS_DATES \
        ARCH_NEWS_LINKS \
        ARCH_NEWS_DESCRIPTIONS \
        >/dev/null 2>&1; then

        POLICY_RESULT="BLOCK"
        POLICY_REASON="Données Arch News indisponibles."
        return
    fi

    if ((${#ARCH_NEWS_NEW_INDEXES[@]} == 0)); then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="Contexte Arch News incohérent : aucune nouvelle annonce indexée."
        return
    fi

    local index
    local title
    local publication_date
    local link
    local description

    for index in "${ARCH_NEWS_NEW_INDEXES[@]}"; do
        title="${ARCH_NEWS_TITLES[$index]-}"
        publication_date="${ARCH_NEWS_DATES[$index]-}"
        link="${ARCH_NEWS_LINKS[$index]-}"
        description="${ARCH_NEWS_DESCRIPTIONS[$index]-}"

        if [[ -z "$title" ||
            -z "$publication_date" ||
            -z "$link" ]]; then

            POLICY_DETAILS=()
            POLICY_RESULT="BLOCK"
            POLICY_REASON="Données incomplètes pour l’annonce Arch News ${index}."
            return
        fi

        if [[ -z "$description" ]]; then
            description="Résumé indisponible."
        fi

        POLICY_DETAILS+=(
            "Titre : ${title} | Date : ${publication_date} | Lien : ${link} | Résumé : ${description}"
        )
    done

    POLICY_RESULT="WARNING"
    POLICY_REASON="${#ARCH_NEWS_NEW_INDEXES[@]} nouvelle(s) annonce(s) Arch Linux à consulter."
}
