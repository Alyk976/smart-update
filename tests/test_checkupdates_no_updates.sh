#!/usr/bin/env bash

set -Eeuo pipefail

TARGET="./bin/smart-update"

[[ -r "$TARGET" ]] || {
    printf 'Erreur : programme principal introuvable.\n' >&2
    exit 1
}

load_updates_block=$(
    awk '
        /^load_updates\(\) \{/ {in_block=1}
        in_block {print}
        in_block && /^\}/ {exit}
    ' "$TARGET"
)

grep -Fq 'if output=$(CHECKUPDATES_DB="$CHECKUPDATES_DB_PATH" checkupdates 2>&1); then' <<<"$load_updates_block" || {
    printf 'Erreur : checkupdates doit être exécuté dans une condition if.\n' >&2
    exit 1
}

grep -Fq 'status=$?' <<<"$load_updates_block" || {
    printf 'Erreur : le code de sortie de checkupdates doit être conservé.\n' >&2
    exit 1
}

if grep -Fq 'set +e' <<<"$load_updates_block"; then
    printf 'Erreur : load_updates ne doit plus désactiver errexit autour de checkupdates.\n' >&2
    exit 1
fi

grep -Fq '2) logger_info "Aucune mise à jour officielle disponible."; return 0 ;;' <<<"$load_updates_block" || {
    printf 'Erreur : le code 2 de checkupdates doit rester un résultat normal.\n' >&2
    exit 1
}

printf 'Le cas checkupdates sans mise à jour est correctement protégé contre le trap ERR.\n'
