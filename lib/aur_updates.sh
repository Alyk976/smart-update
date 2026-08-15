#!/usr/bin/env bash
# shellcheck disable=SC2034

AUR_UPDATES_ERROR=""
declare -a AUR_UPDATE_NAMES=()
declare -a AUR_UPDATE_INSTALLED_VERSIONS=()
declare -a AUR_UPDATE_CANDIDATE_VERSIONS=()
declare -a AUR_APPROVED_PACKAGES=()
declare -a AUR_SKIPPED_UNSTABLE=()

aur_updates_reset() {
    AUR_UPDATES_ERROR=""
    AUR_UPDATE_NAMES=()
    AUR_UPDATE_INSTALLED_VERSIONS=()
    AUR_UPDATE_CANDIDATE_VERSIONS=()
    AUR_APPROVED_PACKAGES=()
    AUR_SKIPPED_UNSTABLE=()
}

aur_updates_fail() {
    AUR_UPDATES_ERROR="${1:?}"
    AUR_UPDATE_NAMES=()
    AUR_UPDATE_INSTALLED_VERSIONS=()
    AUR_UPDATE_CANDIDATE_VERSIONS=()
    AUR_APPROVED_PACKAGES=()
    AUR_SKIPPED_UNSTABLE=()
    return 1
}

aur_updates_collect() {
    local helper="${1:-}" output status line package installed candidate age
    local -A seen_packages=()
    aur_updates_reset

    if output=$(aur_user_run "$helper" -Qua --aur --color never 2>&1); then
        status=0
    else
        status=$?
    fi
    if ((status != 0)); then
        aur_updates_fail "La découverte yay a échoué avec le code ${status}.${output:+ ${output}}"
        return
    fi

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        if [[ "$line" =~ ^([[:alnum:]@._+][[:alnum:]@._+:-]*)[[:space:]]+([^[:space:]]+)[[:space:]]+\-\>[[:space:]]+([^[:space:]\[]+)([[:space:]]+\[([^][]+)\])?$ ]]; then
            package=${BASH_REMATCH[1]}
            installed=${BASH_REMATCH[2]}
            candidate=${BASH_REMATCH[3]}
            age=${BASH_REMATCH[5]:-}
            : "$age"
        else
            aur_updates_fail "Sortie yay incompréhensible : ${line}."
            return
        fi
        if [[ -n "${seen_packages[$package]+defined}" ]]; then
            aur_updates_fail "Paquet AUR dupliqué dans la sortie yay : ${package}."
            return
        fi
        seen_packages["$package"]=1
        AUR_UPDATE_NAMES+=("$package")
        AUR_UPDATE_INSTALLED_VERSIONS+=("$installed")
        AUR_UPDATE_CANDIDATE_VERSIONS+=("$candidate")
    done <<<"$output"
}

aur_updates_classify() {
    local index
    AUR_APPROVED_PACKAGES=()
    AUR_SKIPPED_UNSTABLE=()

    for index in "${!AUR_UPDATE_NAMES[@]}"; do
        if stability_package_is_vcs "${AUR_UPDATE_NAMES[$index]}"; then
            AUR_SKIPPED_UNSTABLE+=("${AUR_UPDATE_NAMES[$index]}|${AUR_UPDATE_CANDIDATE_VERSIONS[$index]}|paquet VCS")
        elif stability_version_is_prerelease "${AUR_UPDATE_CANDIDATE_VERSIONS[$index]}"; then
            AUR_SKIPPED_UNSTABLE+=("${AUR_UPDATE_NAMES[$index]}|${AUR_UPDATE_CANDIDATE_VERSIONS[$index]}|version pré-release")
        else
            AUR_APPROVED_PACKAGES+=("${AUR_UPDATE_NAMES[$index]}")
        fi
    done
}

aur_updates_snapshot() {
    local index
    for index in "${!AUR_UPDATE_NAMES[@]}"; do
        printf '%s|%s|%s\n' \
            "${AUR_UPDATE_NAMES[$index]}" \
            "${AUR_UPDATE_INSTALLED_VERSIONS[$index]}" \
            "${AUR_UPDATE_CANDIDATE_VERSIONS[$index]}"
    done
}
