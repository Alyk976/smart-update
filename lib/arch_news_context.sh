#!/usr/bin/env bash
# shellcheck disable=SC2034

ARCH_NEWS_CONTEXT_DIR=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" \
        && pwd
)
readonly ARCH_NEWS_CONTEXT_DIR

# shellcheck source=lib/arch_news.sh
source "${ARCH_NEWS_CONTEXT_DIR}/arch_news.sh"

# shellcheck source=lib/arch_news_state.sh
source "${ARCH_NEWS_CONTEXT_DIR}/arch_news_state.sh"

ARCH_NEWS_CONTEXT_STATUS=""
ARCH_NEWS_CONTEXT_ERROR=""
ARCH_NEWS_LATEST_GUID=""

arch_news_context_reset() {
    ARCH_NEWS_CONTEXT_STATUS=""
    ARCH_NEWS_CONTEXT_ERROR=""
    ARCH_NEWS_LATEST_GUID=""
}

arch_news_prepare() {
    local enabled="${1:-}"
    local feed_url="${2:-$ARCH_NEWS_FEED_URL}"
    local limit="${3:-}"
    local state_file="${4:-}"

    arch_news_context_reset

    case "$enabled" in
        no)
            ARCH_NEWS_CONTEXT_STATUS="DISABLED"
            return 0
            ;;
        yes)
            ;;
        *)
            ARCH_NEWS_CONTEXT_STATUS="ERROR"
            ARCH_NEWS_CONTEXT_ERROR="Activation Arch News invalide : ${enabled:-undefined}."
            return 1
            ;;
    esac

    if ! arch_news_collect "$feed_url" "$limit"; then
        ARCH_NEWS_CONTEXT_STATUS="ERROR"
        ARCH_NEWS_CONTEXT_ERROR="$ARCH_NEWS_ERROR"
        return 1
    fi

    if ((${#ARCH_NEWS_GUIDS[@]} == 0)); then
        ARCH_NEWS_CONTEXT_STATUS="ERROR"
        ARCH_NEWS_CONTEXT_ERROR="Le flux Arch Linux ne contient aucune annonce."
        return 1
    fi

    ARCH_NEWS_LATEST_GUID="${ARCH_NEWS_GUIDS[0]}"

    if ! arch_news_state_load "$state_file"; then
        ARCH_NEWS_CONTEXT_STATUS="ERROR"
        ARCH_NEWS_CONTEXT_ERROR="$ARCH_NEWS_STATE_ERROR"
        return 1
    fi

    if ! arch_news_state_find_new; then
        ARCH_NEWS_CONTEXT_STATUS="ERROR"
        ARCH_NEWS_CONTEXT_ERROR="$ARCH_NEWS_STATE_ERROR"
        return 1
    fi

    if ((${#ARCH_NEWS_NEW_INDEXES[@]} == 0)); then
        ARCH_NEWS_CONTEXT_STATUS="UP_TO_DATE"
        return 0
    fi

    ARCH_NEWS_CONTEXT_STATUS="NEW"
}
