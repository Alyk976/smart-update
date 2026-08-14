#!/usr/bin/env bash

PACKAGE_ADDITIONS_ERROR=""
declare -a PACKAGE_ADDITIONS=()

package_additions_reset() {
    PACKAGE_ADDITIONS_ERROR=""
    PACKAGE_ADDITIONS=()
}

package_additions_collect() {
    local helper="${1:-}"
    local resolved_helper
    local output
    local error_file
    local helper_error
    local line
    local status
    local -A seen_packages=()

    package_additions_reset

    if [[ -z "$helper" ]]; then
        PACKAGE_ADDITIONS_ERROR="Chemin du collecteur d'ajouts absent."
        return 1
    fi

    if [[ "$helper" == */* ]]; then
        if [[ ! -x "$helper" ]]; then
            PACKAGE_ADDITIONS_ERROR="Collecteur d'ajouts absent ou non exécutable : ${helper}."
            return 1
        fi

        resolved_helper="$helper"
    else
        resolved_helper=$(command -v -- "$helper" 2>/dev/null || true)

        if [[ -z "$resolved_helper" ]]; then
            PACKAGE_ADDITIONS_ERROR="Collecteur d'ajouts introuvable : ${helper}."
            return 1
        fi
    fi

    error_file=$(mktemp)

    if output=$("$resolved_helper" --additions 2>"$error_file"); then
        status=0
    else
        status=$?
    fi

    helper_error=$(<"$error_file")
    rm -f "$error_file"

    if ((status != 0)); then
        PACKAGE_ADDITIONS_ERROR="Le collecteur d'ajouts a échoué avec le code ${status}."

        if [[ -n "$helper_error" ]]; then
            PACKAGE_ADDITIONS_ERROR+=" ${helper_error}"
        fi

        return 1
    fi

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        if [[ ! "$line" =~ ^[a-zA-Z0-9@._+:-]+$ ]]; then
            PACKAGE_ADDITIONS=()
            PACKAGE_ADDITIONS_ERROR="Nom de paquet invalide renvoyé par le collecteur d'ajouts : ${line}."
            return 2
        fi

        if [[ -z "${seen_packages[$line]+defined}" ]]; then
            PACKAGE_ADDITIONS+=("$line")
            seen_packages["$line"]=1
        fi
    done <<<"$output"

    return 0
}
