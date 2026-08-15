#!/usr/bin/env bash
# shellcheck disable=SC2034

AUR_CONTEXT_ERROR=""
AUR_INFO_CLASSIFICATION=""
declare -a AUR_FOREIGN_PACKAGES=()
declare -a AUR_UNKNOWN_FOREIGN=()
declare -a UNKNOWN_FOREIGN_PACKAGES=()

aur_context_classify_info_result() {
    local package="${1:-}" result_code="${2:-}" stdout="${3:-}" stderr="${4:-}"
    local response_repository response_name expected_diagnostic

    AUR_INFO_CLASSIFICATION="ERROR"
    AUR_CONTEXT_ERROR=""

    if [[ ! "$package" =~ ^[[:alnum:]@._+:-]+$ ]]; then
        AUR_CONTEXT_ERROR="Nom de paquet Foreign invalide : ${package:-undefined}."
        return 1
    fi
    if [[ ! "$result_code" =~ ^[0-9]+$ ]]; then
        AUR_CONTEXT_ERROR="Code retour yay invalide pour ${package}."
        return 1
    fi

    if ((result_code == 0)); then
        response_repository=$(awk -F: '/^Repository[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' <<<"$stdout")
        response_name=$(awk -F: '/^Name[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' <<<"$stdout")
        if [[ -n "$stderr" || "$response_repository" != "aur" \
            || "$response_name" != "$package" ]]; then
            AUR_CONTEXT_ERROR="Réponse AUR incohérente pour ${package}."
            return 1
        fi
        AUR_INFO_CLASSIFICATION="AUR_PACKAGE"
        return 0
    fi

    expected_diagnostic=" -> No AUR package found for ${package}"
    if [[ -z "$stdout" && ("$stderr" == "$expected_diagnostic" \
        || "$stderr" == "${expected_diagnostic# -> }") ]]; then
        AUR_INFO_CLASSIFICATION="FOREIGN_NON_AUR"
        return 0
    fi

    AUR_CONTEXT_ERROR="Impossible de classifier le paquet Foreign ${package} : ${stderr:-$stdout}"
    return 1
}

aur_context_collect() {
    local helper="${1:-}" package output error_output status
    local output_file error_file
    local -a foreign_packages=()
    AUR_CONTEXT_ERROR=""
    AUR_FOREIGN_PACKAGES=()
    AUR_UNKNOWN_FOREIGN=()
    UNKNOWN_FOREIGN_PACKAGES=()

    mapfile -t foreign_packages < <(pacman -Qqm 2>/dev/null || true)
    for package in "${foreign_packages[@]}"; do
        output_file=$(mktemp)
        error_file=$(mktemp)
        if aur_user_run_readonly "$helper" -Si --aur --color never "$package" \
            >"$output_file" 2>"$error_file"; then
            status=0
        else
            status=$?
        fi
        output=$(<"$output_file")
        error_output=$(<"$error_file")
        rm -f "$output_file" "$error_file"
        if ! aur_context_classify_info_result \
            "$package" "$status" "$output" "$error_output"; then
            AUR_FOREIGN_PACKAGES=()
            AUR_UNKNOWN_FOREIGN=()
            UNKNOWN_FOREIGN_PACKAGES=()
            return 1
        fi
        case "$AUR_INFO_CLASSIFICATION" in
            AUR_PACKAGE) AUR_FOREIGN_PACKAGES+=("$package") ;;
            FOREIGN_NON_AUR)
                AUR_UNKNOWN_FOREIGN+=("$package")
                UNKNOWN_FOREIGN_PACKAGES+=("$package")
                ;;
        esac
    done
}
