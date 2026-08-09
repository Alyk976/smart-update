#!/usr/bin/env bash

# ==========================================
# Smart Update v2
# Policy Engine
# ==========================================

ENGINE_POLICY_DIR="${LIB_DIR:-${PROJECT_ROOT}/lib}/policies"
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

engine_process_result() {
    local message

    message="Policy ${POLICY_NAME}: ${POLICY_REASON}"

    case "$POLICY_RESULT" in
        ALLOW)
            logger_info "$message"
            ;;
        WARNING)
            logger_warning "$message"
            ;;
        BLOCK)
            logger_blocked "$message"
            ;;
        *)
            logger_error \
                "Résultat invalide pour la politique ${POLICY_NAME}: ${POLICY_RESULT}"
            return 1
            ;;
    esac

    if ((${#POLICY_DETAILS[@]} > 0)); then
        printf '  - %s\n' "${POLICY_DETAILS[@]}" \
            | tee -a "$LOG_FILE"

        if [[ "$POLICY_RESULT" == "BLOCK" ]]; then
            printf '%s\n' "${POLICY_DETAILS[@]}" >>"$BLOCKED_LOG"
        fi
    fi

    decision_add "$POLICY_RESULT" "$POLICY_REASON"
}

engine_run_policies() {
    local policy

    for policy in "${ENGINE_POLICIES[@]}"; do
        unset POLICY_NAME
        unset POLICY_RESULT
        unset POLICY_REASON
        POLICY_DETAILS=()

        # shellcheck disable=SC1090
        source "$policy"

        if ! declare -F policy_run >/dev/null; then
            logger_error "Fonction policy_run absente : ${policy}"
            return 1
        fi

        policy_run

        if [[ -z "${POLICY_NAME:-}" ]]; then
            logger_error "Nom de politique absent : ${policy}"
            unset -f policy_run
            return 1
        fi

        if [[ -z "${POLICY_RESULT:-}" ]]; then
            logger_error "Résultat de politique absent : ${policy}"
            unset -f policy_run
            return 1
        fi

        if [[ -z "${POLICY_REASON:-}" ]]; then
            logger_error "Motif de politique absent : ${policy}"
            unset -f policy_run
            return 1
        fi

        engine_process_result
        unset -f policy_run
    done
}
