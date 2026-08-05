#!/usr/bin/env bash

PACKAGE_REMOVALS_ERROR=""
declare -a PACKAGE_REMOVALS=()

package_removals_reset() {
    PACKAGE_REMOVALS_ERROR=""
    PACKAGE_REMOVALS=()
}

package_removals_collect() {
    local helper="${1:-}"
    local resolved_helper
    local output
    local error_file
    local helper_error
    local line
    local status
    local -A seen_packages=()

    package_removals_reset

    if [[ -z "$helper" ]]; then
        PACKAGE_REMOVALS_ERROR="Chemin du collecteur de suppressions absent."
        return 1
    fi

    if [[ "$helper" == */* ]]; then
        if [[ ! -x "$helper" ]]; then
            PACKAGE_REMOVALS_ERROR="Collecteur de suppressions absent ou non exécutable : ${helper}."
            return 1
        fi

        resolved_helper="$helper"
    else
        resolved_helper=$(command -v -- "$helper" 2>/dev/null || true)

        if [[ -z "$resolved_helper" ]]; then
            PACKAGE_REMOVALS_ERROR="Collecteur de suppressions introuvable : ${helper}."
            return 1
        fi
    fi

    error_file=$(mktemp)

    if output=$("$resolved_helper" 2>"$error_file"); then
        status=0
    else
        status=$?
    fi

    helper_error=$(<"$error_file")
    rm -f "$error_file"

    if ((status != 0)); then
        PACKAGE_REMOVALS_ERROR="Le collecteur de suppressions a échoué avec le code ${status}."

        if [[ -n "$helper_error" ]]; then
            PACKAGE_REMOVALS_ERROR+=" ${helper_error}"
        fi

        return 1
    fi

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        if [[ ! "$line" =~ ^[a-zA-Z0-9@._+:-]+$ ]]; then
            PACKAGE_REMOVALS=()
            PACKAGE_REMOVALS_ERROR="Nom de paquet invalide renvoyé par le collecteur : ${line}."
            return 2
        fi

        if [[ -z "${seen_packages[$line]+defined}" ]]; then
            PACKAGE_REMOVALS+=("$line")
            seen_packages["$line"]=1
        fi
    done <<<"$output"

    return 0
}
