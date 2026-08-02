#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

STATE_FILE="$TEST_DIR/arch-news.last"

# shellcheck source=lib/arch_news_state.sh
source "./lib/arch_news_state.sh"

declare -a ARCH_NEWS_GUIDS=(
    "guid-new"
    "guid-middle"
    "guid-old"
)

# Première exécution : aucun état enregistré
arch_news_state_load "$STATE_FILE"

[[ "$ARCH_NEWS_STATE_EXISTS" == "no" ]]
[[ -z "$ARCH_NEWS_LAST_GUID" ]]
[[ -z "$ARCH_NEWS_STATE_ERROR" ]]

arch_news_state_find_new

((${#ARCH_NEWS_NEW_INDEXES[@]} == 3))
[[ "${ARCH_NEWS_NEW_INDEXES[0]}" == "0" ]]
[[ "${ARCH_NEWS_NEW_INDEXES[1]}" == "1" ]]
[[ "${ARCH_NEWS_NEW_INDEXES[2]}" == "2" ]]

# Le GUID le plus récent est déjà consulté
arch_news_state_save "$STATE_FILE" "guid-new"

[[ -r "$STATE_FILE" ]]
[[ "$(<"$STATE_FILE")" == "guid-new" ]]
[[ "$(stat -c '%a' "$STATE_FILE")" == "640" ]]

arch_news_state_load "$STATE_FILE"
arch_news_state_find_new

[[ "$ARCH_NEWS_STATE_EXISTS" == "yes" ]]
[[ "$ARCH_NEWS_LAST_GUID" == "guid-new" ]]
((${#ARCH_NEWS_NEW_INDEXES[@]} == 0))

# Une annonce est plus récente que le dernier GUID consulté
arch_news_state_save "$STATE_FILE" "guid-middle"

arch_news_state_load "$STATE_FILE"
arch_news_state_find_new

((${#ARCH_NEWS_NEW_INDEXES[@]} == 1))
[[ "${ARCH_NEWS_NEW_INDEXES[0]}" == "0" ]]

# Le GUID enregistré est absent du flux collecté
printf '%s\n' "guid-unknown" >"$STATE_FILE"

arch_news_state_load "$STATE_FILE"

if arch_news_state_find_new; then
    printf 'Erreur : un GUID absent du flux a été accepté.\n' >&2
    exit 1
fi

[[ "$ARCH_NEWS_STATE_ERROR" == "Le dernier GUID consulté est absent du flux collecté." ]]

((${#ARCH_NEWS_NEW_INDEXES[@]} == 0))

# Le fichier d’état contient plusieurs lignes
printf '%s\n' "guid-new" "guid-old" >"$STATE_FILE"

if arch_news_state_load "$STATE_FILE"; then
    printf "Erreur : un fichier d’état invalide a été accepté.\n" >&2
    exit 1
fi

[[ "$ARCH_NEWS_STATE_ERROR" == "Fichier d’état Arch News invalide." ]]

printf "Tous les tests de l’état Arch News ont réussi.\n"
