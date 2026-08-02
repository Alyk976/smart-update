#!/usr/bin/env bash
# shellcheck disable=SC2034

ARCH_NEWS_STATE_ERROR=""
ARCH_NEWS_LAST_GUID=""
ARCH_NEWS_STATE_EXISTS="no"

declare -a ARCH_NEWS_NEW_INDEXES=()

arch_news_state_reset() {
    ARCH_NEWS_STATE_ERROR=""
    ARCH_NEWS_LAST_GUID=""
    ARCH_NEWS_STATE_EXISTS="no"
    ARCH_NEWS_NEW_INDEXES=()
}

arch_news_state_load() {
    local state_file="${1:-}"

    arch_news_state_reset

    if [[ -z "$state_file" ]]; then
        ARCH_NEWS_STATE_ERROR="Chemin du fichier d’état absent."
        return 1
    fi

    if [[ ! -e "$state_file" ]]; then
        return 0
    fi

    if [[ ! -r "$state_file" ]]; then
        ARCH_NEWS_STATE_ERROR="Fichier d’état illisible : ${state_file}."
        return 1
    fi

    local -a state_lines=()

    mapfile -t state_lines <"$state_file"

    if ((${#state_lines[@]} != 1)) \
        || [[ -z "${state_lines[0]}" ]]; then

        ARCH_NEWS_STATE_ERROR="Fichier d’état Arch News invalide."
        return 1
    fi

    ARCH_NEWS_LAST_GUID="${state_lines[0]}"
    ARCH_NEWS_STATE_EXISTS="yes"
}

arch_news_state_find_new() {
    local last_guid="${1:-${ARCH_NEWS_LAST_GUID:-}}"

    ARCH_NEWS_STATE_ERROR=""
    ARCH_NEWS_NEW_INDEXES=()

    if ! declare -p ARCH_NEWS_GUIDS >/dev/null 2>&1; then
        ARCH_NEWS_STATE_ERROR="Aucune collection Arch News disponible."
        return 1
    fi

    if ((${#ARCH_NEWS_GUIDS[@]} == 0)); then
        return 0
    fi

    local index

    if [[ -z "$last_guid" ]]; then
        for index in "${!ARCH_NEWS_GUIDS[@]}"; do
            ARCH_NEWS_NEW_INDEXES+=("$index")
        done

        return 0
    fi

    local guid_found="no"

    for index in "${!ARCH_NEWS_GUIDS[@]}"; do
        if [[ "${ARCH_NEWS_GUIDS[$index]}" == "$last_guid" ]]; then
            guid_found="yes"
            break
        fi

        ARCH_NEWS_NEW_INDEXES+=("$index")
    done

    if [[ "$guid_found" != "yes" ]]; then
        ARCH_NEWS_NEW_INDEXES=()
        ARCH_NEWS_STATE_ERROR="Le dernier GUID consulté est absent du flux collecté."
        return 2
    fi
}

arch_news_state_save() {
    local state_file="${1:-}"
    local guid="${2:-}"

    ARCH_NEWS_STATE_ERROR=""

    if [[ -z "$state_file" ]]; then
        ARCH_NEWS_STATE_ERROR="Chemin du fichier d’état absent."
        return 1
    fi

    if [[ -z "$guid" ||
        "$guid" == *$'\n'* ||
        "$guid" == *$'\r'* ]]; then

        ARCH_NEWS_STATE_ERROR="GUID Arch News invalide."
        return 1
    fi

    local state_directory="${state_file%/*}"

    if [[ "$state_directory" == "$state_file" ]]; then
        state_directory="."
    fi

    if [[ ! -d "$state_directory" ]]; then
        ARCH_NEWS_STATE_ERROR="Répertoire d’état absent : ${state_directory}."
        return 1
    fi

    local temporary_file

    if ! temporary_file=$(
        mktemp "${state_directory}/.arch-news.last.XXXXXX"
    ); then
        ARCH_NEWS_STATE_ERROR="Impossible de créer le fichier d’état temporaire."
        return 1
    fi

    if ! printf '%s\n' "$guid" >"$temporary_file"; then
        rm -f "$temporary_file"
        ARCH_NEWS_STATE_ERROR="Impossible d’écrire le GUID Arch News."
        return 1
    fi

    if ! chmod 640 "$temporary_file"; then
        rm -f "$temporary_file"
        ARCH_NEWS_STATE_ERROR="Impossible de sécuriser le fichier d’état."
        return 1
    fi

    if ! mv -f -- "$temporary_file" "$state_file"; then
        rm -f "$temporary_file"
        ARCH_NEWS_STATE_ERROR="Impossible d’enregistrer l’état Arch News."
        return 1
    fi

    ARCH_NEWS_LAST_GUID="$guid"
    ARCH_NEWS_STATE_EXISTS="yes"
}
