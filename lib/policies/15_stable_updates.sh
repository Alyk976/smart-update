#!/usr/bin/env bash
# shellcheck disable=SC2034

policy_run() {
    POLICY_NAME="stable_updates"
    POLICY_DETAILS=()

    if [[ -n "${PACKAGE_CANDIDATES_ERROR:-}" ]]; then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="Métadonnées de stabilité indisponibles."
        POLICY_DETAILS=("${PACKAGE_CANDIDATES_ERROR}")
        return
    fi

    local repository_count=${#PACKAGE_CANDIDATE_REPOS[@]}
    local name_count=${#PACKAGE_CANDIDATE_NAMES[@]}
    local version_count=${#PACKAGE_CANDIDATE_VERSIONS[@]}

    if ! ((repository_count == name_count && repository_count == version_count)); then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="Métadonnées de stabilité incohérentes."
        POLICY_DETAILS=("Les tableaux de candidats n'ont pas la même taille.")
        return
    fi

    local index
    for index in "${!PACKAGE_CANDIDATE_REPOS[@]}"; do
        if ! stability_candidate_is_stable \
            "${PACKAGE_CANDIDATE_REPOS[$index]}" \
            "${PACKAGE_CANDIDATE_NAMES[$index]}" \
            "${PACKAGE_CANDIDATE_VERSIONS[$index]}"; then
            POLICY_DETAILS+=(
                "${PACKAGE_CANDIDATE_REPOS[$index]}/${PACKAGE_CANDIDATE_NAMES[$index]}/${PACKAGE_CANDIDATE_VERSIONS[$index]} : ${STABILITY_REASON}"
            )
        fi
    done

    if ((${#POLICY_DETAILS[@]} > 0)); then
        POLICY_RESULT="BLOCK"
        POLICY_REASON="Candidats de mise à jour non stables ou non officiels détectés :"
    else
        POLICY_RESULT="ALLOW"
        POLICY_REASON="Tous les candidats officiels sont stables."
    fi
}
