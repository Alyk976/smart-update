#!/usr/bin/env bash
# shellcheck disable=SC2034

readonly ARCH_NEWS_FEED_URL="https://archlinux.org/feeds/news/"

ARCH_NEWS_ERROR=""

declare -a ARCH_NEWS_GUIDS=()
declare -a ARCH_NEWS_TITLES=()
declare -a ARCH_NEWS_DATES=()
declare -a ARCH_NEWS_LINKS=()
declare -a ARCH_NEWS_DESCRIPTIONS=()

arch_news_reset() {
    ARCH_NEWS_ERROR=""

    ARCH_NEWS_GUIDS=()
    ARCH_NEWS_TITLES=()
    ARCH_NEWS_DATES=()
    ARCH_NEWS_LINKS=()
    ARCH_NEWS_DESCRIPTIONS=()
}

arch_news_normalize_description() {
    local description="${1:-}"

    printf '%s' "$description" \
        | sed -E 's/<[^>]+>/ /g' \
        | tr '\n\r\t' '   ' \
        | sed -E \
            -e 's/[[:space:]]+/ /g' \
            -e 's/^ //' \
            -e 's/ $//'
}

arch_news_xpath_string() {
    local feed_file="$1"
    local xpath="$2"

    xmllint \
        --xpath "string(${xpath})" \
        "$feed_file" \
        2>/dev/null
}

arch_news_parse_file() {
    local feed_file="${1:-}"
    local limit="${2:-}"

    arch_news_reset

    if [[ ! -r "$feed_file" ]]; then
        ARCH_NEWS_ERROR="Flux RSS absent ou illisible."
        return 1
    fi

    if [[ ! "$limit" =~ ^[0-9]+$ ]] || ((limit <= 0)); then
        ARCH_NEWS_ERROR="Limite d’annonces invalide : ${limit:-undefined}."
        return 1
    fi

    local item_count

    if ! item_count=$(
        xmllint \
            --xpath 'count(/rss/channel/item)' \
            "$feed_file" \
            2>/dev/null
    ); then
        ARCH_NEWS_ERROR="Flux RSS Arch Linux invalide."
        return 2
    fi

    item_count=${item_count%%.*}

    if [[ ! "$item_count" =~ ^[0-9]+$ ]]; then
        ARCH_NEWS_ERROR="Nombre d’annonces RSS invalide."
        return 2
    fi

    if ((item_count > limit)); then
        item_count=$limit
    fi

    local index
    local guid
    local title
    local publication_date
    local link
    local description

    for ((index = 1; index <= item_count; index++)); do
        guid=$(arch_news_xpath_string \
            "$feed_file" \
            "/rss/channel/item[${index}]/guid")

        title=$(arch_news_xpath_string \
            "$feed_file" \
            "/rss/channel/item[${index}]/title")

        publication_date=$(arch_news_xpath_string \
            "$feed_file" \
            "/rss/channel/item[${index}]/pubDate")

        link=$(arch_news_xpath_string \
            "$feed_file" \
            "/rss/channel/item[${index}]/link")

        description=$(arch_news_xpath_string \
            "$feed_file" \
            "/rss/channel/item[${index}]/description")

        if [[ -z "$guid" ||
            -z "$title" ||
            -z "$publication_date" ||
            -z "$link" ]]; then

            ARCH_NEWS_GUIDS=()
            ARCH_NEWS_TITLES=()
            ARCH_NEWS_DATES=()
            ARCH_NEWS_LINKS=()
            ARCH_NEWS_DESCRIPTIONS=()

            ARCH_NEWS_ERROR="Annonce RSS incomplète à la position ${index}."
            return 2
        fi

        description=$(arch_news_normalize_description "$description")

        ARCH_NEWS_GUIDS+=("$guid")
        ARCH_NEWS_TITLES+=("$title")
        ARCH_NEWS_DATES+=("$publication_date")
        ARCH_NEWS_LINKS+=("$link")
        ARCH_NEWS_DESCRIPTIONS+=("$description")
    done
}

arch_news_collect() {
    local feed_url="${1:-$ARCH_NEWS_FEED_URL}"
    local limit="${2:-}"
    local temporary_file
    local status

    arch_news_reset

    if ! temporary_file=$(mktemp); then
        ARCH_NEWS_ERROR="Impossible de créer le fichier RSS temporaire."
        return 1
    fi

    if ! curl \
        --fail \
        --silent \
        --show-error \
        --max-time 20 \
        --output "$temporary_file" \
        "$feed_url"; then

        rm -f "$temporary_file"
        ARCH_NEWS_ERROR="Impossible de télécharger le flux Arch Linux."
        return 3
    fi

    set +e
    arch_news_parse_file "$temporary_file" "$limit"
    status=$?
    set -e

    rm -f "$temporary_file"

    return "$status"
}
