#!/usr/bin/env bash
# shellcheck disable=SC2034

AUR_HELPER_CAPABILITY="NOT_CHECKED"
AUR_HELPER_CAPABILITY_ERROR=""
AUR_HELPER_VERSION=""
AUR_HELPER_RECHECK_REQUIRED="no"

aur_helper_capability_reset() {
    AUR_HELPER_CAPABILITY="NOT_CHECKED"
    AUR_HELPER_CAPABILITY_ERROR=""
    AUR_HELPER_VERSION=""
}

aur_helper_detect_official_recheck() {
    local package

    AUR_HELPER_RECHECK_REQUIRED="no"
    for package in "${PACKAGE_CANDIDATE_NAMES[@]}"; do
        if [[ "$package" == "pacman" ]]; then
            AUR_HELPER_RECHECK_REQUIRED="yes"
            return 0
        fi
    done
}

aur_helper_capability_check() {
    local helper_path="" version_output="" help_output="" version_major=""

    aur_helper_capability_reset
    helper_path=$(command -v -- "$AUR_HELPER" 2>/dev/null || true)
    if [[ -z "$helper_path" || ! -x "$helper_path" ]]; then
        AUR_HELPER_CAPABILITY="NOT_INSTALLED"
        AUR_HELPER_CAPABILITY_ERROR="AUR phase unavailable: yay not installed"
        return 1
    fi
    AUR_HELPER_PATH="$helper_path"

    if ! aur_user_resolve "$AUR_USER"; then
        AUR_HELPER_CAPABILITY="USER_CONTEXT_UNAVAILABLE"
        AUR_HELPER_CAPABILITY_ERROR="$AUR_USER_ERROR"
        return 1
    fi

    if ! version_output=$(aur_user_run "$helper_path" --version 2>&1); then
        AUR_HELPER_CAPABILITY="INCOMPATIBLE"
        AUR_HELPER_CAPABILITY_ERROR="yay --version failed; yay or libalpm is incompatible."
        return 1
    fi
    if [[ ! "$version_output" =~ yay[[:space:]]v([0-9]+)\.[0-9]+\.[0-9]+[[:space:]]-[[:space:]]libalpm[[:space:]]v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        AUR_HELPER_CAPABILITY="INCOMPATIBLE"
        AUR_HELPER_CAPABILITY_ERROR="Unsupported yay --version output."
        return 1
    fi
    version_major="${BASH_REMATCH[1]}"
    if ((version_major < 13)); then
        AUR_HELPER_CAPABILITY="INCOMPATIBLE"
        AUR_HELPER_CAPABILITY_ERROR="yay 13 or newer is required."
        return 1
    fi

    if ! help_output=$(aur_user_run "$helper_path" --help 2>&1); then
        AUR_HELPER_CAPABILITY="INCOMPATIBLE"
        AUR_HELPER_CAPABILITY_ERROR="yay --help failed."
        return 1
    fi
    for required_option in --aur --color --needed --noconfirm; do
        if ! grep -Fq -- "$required_option" <<<"$help_output"; then
            AUR_HELPER_CAPABILITY="INCOMPATIBLE"
            AUR_HELPER_CAPABILITY_ERROR="yay lacks required option ${required_option}."
            return 1
        fi
    done

    AUR_HELPER_VERSION="$version_output"
    AUR_HELPER_CAPABILITY="READY"
}
