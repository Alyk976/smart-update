#!/usr/bin/env bash
# shellcheck disable=SC2034

AUR_RESULT="NOT_RUN"
AUR_PHASE_ERROR=""
AUR_HELPER_PATH=""
AUR_DETECTED_COUNT=0
AUR_HELPER_POST_UPDATE_STATUS="NOT_CHECKED"
declare -a AUR_INSTALLED_PACKAGES=()

aur_phase_reset() {
    AUR_RESULT="NOT_RUN"
    AUR_PHASE_ERROR=""
    AUR_HELPER_PATH=""
    AUR_DETECTED_COUNT=0
    AUR_HELPER_POST_UPDATE_STATUS="NOT_CHECKED"
    AUR_INSTALLED_PACKAGES=()
    AUR_CONTEXT_ERROR=""
    AUR_FOREIGN_PACKAGES=()
    AUR_UNKNOWN_FOREIGN=()
    UNKNOWN_FOREIGN_PACKAGES=()
    aur_updates_reset
}

aur_phase_prepare() {
    aur_phase_reset

    if [[ "$ENABLE_AUR_UPDATES" == "no" ]]; then
        mapfile -t UNKNOWN_FOREIGN_PACKAGES < <(pacman -Qqm 2>/dev/null || true)
        AUR_RESULT="DISABLED"
        return 0
    fi

    if ! aur_helper_capability_check; then
        mapfile -t UNKNOWN_FOREIGN_PACKAGES < <(pacman -Qqm 2>/dev/null || true)
        AUR_RESULT="NOT_AVAILABLE"
        AUR_PHASE_ERROR="$AUR_HELPER_CAPABILITY_ERROR"
        return 0
    fi

    if ! aur_context_collect "$AUR_HELPER_PATH"; then
        AUR_RESULT="FAILED"
        AUR_PHASE_ERROR="$AUR_CONTEXT_ERROR"
        return 1
    fi
    if ! aur_updates_collect "$AUR_HELPER_PATH"; then
        AUR_RESULT="FAILED"
        AUR_PHASE_ERROR="$AUR_UPDATES_ERROR"
        return 1
    fi
    aur_updates_classify
    AUR_DETECTED_COUNT=${#AUR_UPDATE_NAMES[@]}
    AUR_RESULT="ANALYZED"
}

aur_phase_execute() {
    local analyzed_snapshot current_snapshot status

    case "$AUR_RESULT" in
        DISABLED | NOT_AVAILABLE) return 0 ;;
        FAILED) return "$EXIT_AUR_DISCOVERY_FAILED" ;;
    esac

    if [[ "$MODE" == "audit" ]]; then
        return 0
    fi

    if ! aur_helper_capability_check; then
        AUR_HELPER_POST_UPDATE_STATUS="$AUR_HELPER_CAPABILITY"
        AUR_RESULT="DEFERRED_HELPER_INCOMPATIBLE"
        AUR_PHASE_ERROR="Official update succeeded; AUR deferred because yay is incompatible or unavailable after the official libalpm update: ${AUR_HELPER_CAPABILITY_ERROR}"
        return "$EXIT_AUR_DISCOVERY_FAILED"
    fi
    AUR_HELPER_POST_UPDATE_STATUS="READY"

    if ! aur_updates_collect "$AUR_HELPER_PATH"; then
        AUR_RESULT="FAILED"
        AUR_PHASE_ERROR="$AUR_UPDATES_ERROR"
        return "$EXIT_AUR_DISCOVERY_FAILED"
    fi
    aur_updates_classify
    analyzed_snapshot=$(aur_updates_snapshot)
    AUR_DETECTED_COUNT=${#AUR_UPDATE_NAMES[@]}

    if ! aur_updates_collect "$AUR_HELPER_PATH"; then
        AUR_RESULT="FAILED"
        AUR_PHASE_ERROR="$AUR_UPDATES_ERROR"
        return "$EXIT_AUR_DISCOVERY_FAILED"
    fi
    current_snapshot=$(aur_updates_snapshot)
    if [[ "$current_snapshot" != "$analyzed_snapshot" ]]; then
        AUR_RESULT="FAILED"
        AUR_PHASE_ERROR="Les candidats AUR ont changé entre analyse et installation (anti-TOCTOU)."
        return "$EXIT_AUR_DISCOVERY_FAILED"
    fi
    aur_updates_classify

    if ((${#AUR_APPROVED_PACKAGES[@]} == 0)); then
        AUR_RESULT="SKIPPED"
        return 0
    fi

    set +e
    aur_user_run "$AUR_HELPER_PATH" \
        -S --aur --needed --noconfirm --color never \
        "${AUR_APPROVED_PACKAGES[@]}" 2>&1 | tee -a "$LOG_FILE"
    status=${PIPESTATUS[0]}
    set -e
    if ((status != 0)); then
        AUR_RESULT="FAILED"
        AUR_PHASE_ERROR="yay a échoué avec le code ${status}."
        return "$EXIT_AUR_UPDATE_FAILED"
    fi

    AUR_INSTALLED_PACKAGES=("${AUR_APPROVED_PACKAGES[@]}")
    AUR_RESULT="INSTALLED"
}
