#!/usr/bin/env bash

# ==========================================
# Smart Update v2
# Policy Engine
# ==========================================

ENGINE_POLICY_DIR="${PROJECT_ROOT}/lib/policies"

ENGINE_POLICIES=()

engine_load_policies() {
    ENGINE_POLICIES=()

    local file

    shopt -s nullglob

    for file in "${ENGINE_POLICY_DIR}"/*.sh; do
        ENGINE_POLICIES+=("$file")
    done

    shopt -u nullglob
}

engine_run_policies() {

    local policy

    for policy in "${ENGINE_POLICIES[@]}"; do

        unset POLICY_RESULT
        unset POLICY_REASON

        source "$policy"

        if declare -F policy_run >/dev/null; then
            policy_run

            decision_add \
                "${POLICY_RESULT:-ALLOW}" \
                "${POLICY_REASON:-No reason provided}"
        fi

        unset -f policy_run
    done
}
