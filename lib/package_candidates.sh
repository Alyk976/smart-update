#!/usr/bin/env bash
# shellcheck disable=SC2034

PACKAGE_CANDIDATES_ERROR=""
declare -a PACKAGE_CANDIDATE_REPOS=()
declare -a PACKAGE_CANDIDATE_NAMES=()
declare -a PACKAGE_CANDIDATE_VERSIONS=()

package_candidates_reset() {
    PACKAGE_CANDIDATES_ERROR=""
    PACKAGE_CANDIDATE_REPOS=()
    PACKAGE_CANDIDATE_NAMES=()
    PACKAGE_CANDIDATE_VERSIONS=()
}

package_candidates_fail() {
    PACKAGE_CANDIDATES_ERROR="${1:?}"
    PACKAGE_CANDIDATE_REPOS=()
    PACKAGE_CANDIDATE_NAMES=()
    PACKAGE_CANDIDATE_VERSIONS=()
    return 1
}

package_candidates_collect() {
    local helper="${1:-}" resolved_helper output error_file helper_error status
    local line repository package version remainder

    package_candidates_reset

    if [[ -z "$helper" ]]; then
        package_candidates_fail "Chemin du collecteur de candidats absent."
        return
    fi

    if [[ "$helper" == */* ]]; then
        [[ -x "$helper" ]] || {
            package_candidates_fail "Collecteur de candidats absent ou non exécutable : ${helper}."
            return
        }
        resolved_helper="$helper"
    else
        resolved_helper=$(command -v -- "$helper" 2>/dev/null || true)
        [[ -n "$resolved_helper" ]] || {
            package_candidates_fail "Collecteur de candidats introuvable : ${helper}."
            return
        }
    fi

    error_file=$(mktemp)
    if output=$("$resolved_helper" --additions-meta 2>"$error_file"); then
        status=0
    else
        status=$?
    fi
    helper_error=$(<"$error_file")
    rm -f "$error_file"

    if ((status != 0)); then
        package_candidates_fail "Le collecteur de candidats a échoué avec le code ${status}.${helper_error:+ ${helper_error}}"
        return
    fi

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        IFS='|' read -r repository package version remainder <<<"$line"

        if [[ -n "${remainder:-}" || "$line" != *'|'* || "${line#*|}" != *'|'* ]]; then
            package_candidates_fail "Métadonnées de candidat mal formées : ${line}."
            return
        fi
        if [[ -z "$repository" || -z "$package" || -z "$version" ]]; then
            package_candidates_fail "Champ vide dans les métadonnées de candidat : ${line}."
            return
        fi
        if [[ ! "$repository" =~ ^[[:alnum:]][[:alnum:]_.-]*$ ]]; then
            package_candidates_fail "Nom de dépôt invalide : ${repository}."
            return
        fi
        if [[ ! "$package" =~ ^[[:alnum:]@._+:-]+$ ]]; then
            package_candidates_fail "Nom de paquet invalide : ${package}."
            return
        fi
        if [[ "$version" == *'|'* || "$version" =~ [[:cntrl:]] ]]; then
            package_candidates_fail "Version de paquet invalide : ${version}."
            return
        fi

        PACKAGE_CANDIDATE_REPOS+=("$repository")
        PACKAGE_CANDIDATE_NAMES+=("$package")
        PACKAGE_CANDIDATE_VERSIONS+=("$version")
    done <<<"$output"
}
