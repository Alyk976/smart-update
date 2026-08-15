#!/usr/bin/env bash
# shellcheck disable=SC2034

STABILITY_REASON=""

stability_repository_is_official_stable() {
    case "${1,,}" in
        core | extra | multilib) return 0 ;;
        *) return 1 ;;
    esac
}

stability_repository_reason() {
    local repository="${1,,}"

    if stability_repository_is_official_stable "$repository"; then
        return 1
    fi

    case "$repository" in
        *-testing | *-staging | *-unstable)
            printf 'dépôt de développement interdit'
            ;;
        *)
            printf 'dépôt tiers ou non reconnu'
            ;;
    esac
}

stability_package_is_vcs() {
    [[ "${1,,}" =~ -(git|svn|hg|bzr|cvs|darcs)$ ]]
}

stability_version_is_prerelease() {
    local version="${1,,}"
    [[ "$version" =~ (^|[^[:alnum:]])(alpha|beta|rc|pre|preview|dev|nightly|snapshot)[0-9]*([^[:alnum:]]|$) ]]
}

stability_candidate_is_stable() {
    local repository="${1:-}" package="${2:-}" version="${3:-}"
    STABILITY_REASON=""

    if [[ -z "$repository" || -z "$package" || -z "$version" ]]; then
        STABILITY_REASON="métadonnées absentes ou incomplètes"
        return 1
    fi
    if ! stability_repository_is_official_stable "$repository"; then
        STABILITY_REASON=$(stability_repository_reason "$repository")
        return 1
    fi
    if stability_package_is_vcs "$package"; then
        STABILITY_REASON="paquet VCS ou de développement"
        return 1
    fi
    if stability_version_is_prerelease "$version"; then
        STABILITY_REASON="version pré-release explicite"
        return 1
    fi
    return 0
}
