#!/usr/bin/env bash
# shellcheck disable=SC2034

AUR_USER_ERROR=""
AUR_EXEC_USER=""
AUR_EXEC_UID=""
AUR_EXEC_GID=""
AUR_EXEC_HOME=""

aur_user_reset() {
    AUR_USER_ERROR=""
    AUR_EXEC_USER=""
    AUR_EXEC_UID=""
    AUR_EXEC_GID=""
    AUR_EXEC_HOME=""
}

aur_user_resolve() {
    local configured_user="${1:-}" candidate passwd_entry shell

    aur_user_reset

    if [[ "$configured_user" == "auto" ]]; then
        if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == "root" ]]; then
            AUR_USER_ERROR="AUR_USER=auto sans SUDO_USER non-root fiable."
            return 1
        fi
        candidate="$SUDO_USER"
    else
        candidate="$configured_user"
    fi

    if [[ -z "$candidate" || "$candidate" == "root"
        || ! "$candidate" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        AUR_USER_ERROR="Utilisateur AUR invalide : ${candidate:-undefined}."
        return 1
    fi

    passwd_entry=$(getent passwd "$candidate" 2>/dev/null) || {
        AUR_USER_ERROR="Utilisateur AUR inexistant : ${candidate}."
        return 1
    }
    IFS=: read -r _ _ AUR_EXEC_UID AUR_EXEC_GID _ AUR_EXEC_HOME shell \
        <<<"$passwd_entry"

    if [[ ! "$AUR_EXEC_UID" =~ ^[0-9]+$ || "$AUR_EXEC_UID" -eq 0 ]]; then
        AUR_USER_ERROR="L'utilisateur AUR doit avoir un UID non-root."
        aur_user_reset_preserve_error
        return 1
    fi
    if [[ ! "$AUR_EXEC_GID" =~ ^[0-9]+$ || ! -d "$AUR_EXEC_HOME" ]]; then
        AUR_USER_ERROR="Home ou GID inutilisable pour l'utilisateur AUR ${candidate}."
        aur_user_reset_preserve_error
        return 1
    fi
    case "$shell" in
        "" | */false | */nologin)
            AUR_USER_ERROR="Shell inutilisable pour l'utilisateur AUR ${candidate}."
            aur_user_reset_preserve_error
            return 1
            ;;
    esac

    AUR_EXEC_USER="$candidate"
}

aur_user_reset_preserve_error() {
    local error="$AUR_USER_ERROR"
    aur_user_reset
    AUR_USER_ERROR="$error"
}

aur_user_run() {
    [[ -n "$AUR_EXEC_USER" && -n "$AUR_EXEC_UID" \
        && -n "$AUR_EXEC_GID" && -n "$AUR_EXEC_HOME" ]] || return 125
    env -i \
        HOME="$AUR_EXEC_HOME" \
        USER="$AUR_EXEC_USER" \
        LOGNAME="$AUR_EXEC_USER" \
        SUDO_USER="$AUR_EXEC_USER" \
        SUDO_UID="$AUR_EXEC_UID" \
        SUDO_GID="$AUR_EXEC_GID" \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        LC_ALL=C \
        "$@"
}

aur_user_run_readonly() {
    [[ -n "$AUR_EXEC_USER" && -n "$AUR_EXEC_HOME" ]] || return 125
    local -a identity_prefix=()

    if ((EUID != AUR_EXEC_UID)); then
        identity_prefix=(runuser -u "$AUR_EXEC_USER" --)
    fi

    "${identity_prefix[@]}" env -i \
        HOME="$AUR_EXEC_HOME" \
        USER="$AUR_EXEC_USER" \
        LOGNAME="$AUR_EXEC_USER" \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        LC_ALL=C \
        "$@"
}
