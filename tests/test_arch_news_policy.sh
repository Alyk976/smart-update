#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/policies/40_arch_news.sh
source "./lib/policies/40_arch_news.sh"

ARCH_NEWS_CONTEXT_STATUS="DISABLED"
ARCH_NEWS_CONTEXT_ERROR=""

policy_run

[[ "$POLICY_NAME" == "arch_news" ]]
[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Consultation des annonces Arch Linux désactivée." ]]
((${#POLICY_DETAILS[@]} == 0))

ARCH_NEWS_CONTEXT_STATUS="UP_TO_DATE"

policy_run

[[ "$POLICY_RESULT" == "ALLOW" ]]
[[ "$POLICY_REASON" == "Aucune nouvelle annonce Arch Linux." ]]
((${#POLICY_DETAILS[@]} == 0))

ARCH_NEWS_CONTEXT_STATUS="ERROR"
ARCH_NEWS_CONTEXT_ERROR="Impossible de télécharger le flux Arch Linux."

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Impossible de télécharger le flux Arch Linux." ]]
((${#POLICY_DETAILS[@]} == 0))

ARCH_NEWS_CONTEXT_STATUS="NEW"
ARCH_NEWS_CONTEXT_ERROR=""

declare -a ARCH_NEWS_NEW_INDEXES=(0 1)

declare -a ARCH_NEWS_TITLES=(
    "Première annonce"
    "Deuxième annonce"
)

declare -a ARCH_NEWS_DATES=(
    "Sun, 02 Aug 2026 10:00:00 +0000"
    "Sat, 01 Aug 2026 10:00:00 +0000"
)

declare -a ARCH_NEWS_LINKS=(
    "https://archlinux.org/news/first/"
    "https://archlinux.org/news/second/"
)

declare -a ARCH_NEWS_DESCRIPTIONS=(
    "Première information importante."
    "Deuxième information importante."
)

policy_run

[[ "$POLICY_RESULT" == "WARNING" ]]
[[ "$POLICY_REASON" == "2 nouvelle(s) annonce(s) Arch Linux à consulter." ]]
((${#POLICY_DETAILS[@]} == 2))

[[ "${POLICY_DETAILS[0]}" == "Titre : Première annonce | Date : Sun, 02 Aug 2026 10:00:00 +0000 | Lien : https://archlinux.org/news/first/ | Résumé : Première information importante." ]]

[[ "${POLICY_DETAILS[1]}" == "Titre : Deuxième annonce | Date : Sat, 01 Aug 2026 10:00:00 +0000 | Lien : https://archlinux.org/news/second/ | Résumé : Deuxième information importante." ]]

ARCH_NEWS_NEW_INDEXES=()

policy_run

[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "$POLICY_REASON" == "Contexte Arch News incohérent : aucune nouvelle annonce indexée." ]]
((${#POLICY_DETAILS[@]} == 0))

printf "Tous les tests de la politique Arch News ont réussi.\n"
