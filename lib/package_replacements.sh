#!/usr/bin/env bash

PACKAGE_REPLACEMENTS_ERROR=""
declare -a PACKAGE_REPLACEMENTS=()

package_replacements_reset() {
    PACKAGE_REPLACEMENTS_ERROR=""
    PACKAGE_REPLACEMENTS=()
}

package_replacements_collect() {
    local helper="${1:-}"
    local resolved_helper
    local output
    local error_file
    local helper_error
    local line
    local old_package
    local new_package
    local status
    local -A seen_replacements=()

    package_replacements_reset

    if [[ -z "$helper" ]]; then
        PACKAGE_REPLACEMENTS_ERROR="Chemin du collecteur de remplacements absent."
        return 1
    fi

    if [[ "$helper" == */* ]]; then
        if [[ ! -x "$helper" ]]; then
            PACKAGE_REPLACEMENTS_ERROR="Collecteur de remplacements absent ou non exécutable : ${helper}."
            return 1
        fi

        resolved_helper="$helper"
    else
        resolved_helper=$(command -v -- "$helper" 2>/dev/null || true)

        if [[ -z "$resolved_helper" ]]; then
            PACKAGE_REPLACEMENTS_ERROR="Collecteur de remplacements introuvable : ${helper}."
            return 1
        fi
    fi

    error_file=$(mktemp)

    if output=$("$resolved_helper" --replacements 2>"$error_file"); then
        status=0
    else
        status=$?
    fi

    helper_error=$(<"$error_file")
    rm -f "$error_file"

    if ((status != 0)); then
        PACKAGE_REPLACEMENTS_ERROR="Le collecteur de remplacements a échoué avec le code ${status}."

        if [[ -n "$helper_error" ]]; then
            PACKAGE_REPLACEMENTS_ERROR+=" ${helper_error}"
        fi

        return 1
    fi

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        if [[ "$line" != *"|"* ]]; then
            PACKAGE_REPLACEMENTS=()
            PACKAGE_REPLACEMENTS_ERROR="Remplacement invalide renvoyé par le collecteur : ${line}."
            return 2
        fi

        old_package=${line%%|*}
        new_package=${line#*|}

        if [[ -z "$old_package" || -z "$new_package" \
            || "$new_package" == *"|"* \
            || ! "$old_package" =~ ^[a-zA-Z0-9@._+:-]+$ \
            || ! "$new_package" =~ ^[a-zA-Z0-9@._+:-]+$ ]]; then
            PACKAGE_REPLACEMENTS=()
            PACKAGE_REPLACEMENTS_ERROR="Remplacement invalide renvoyé par le collecteur : ${line}."
            return 2
        fi

        if [[ -z "${seen_replacements[$line]+defined}" ]]; then
            PACKAGE_REPLACEMENTS+=("$line")
            seen_replacements["$line"]=1
        fi
    done <<<"$output"

    return 0
}
