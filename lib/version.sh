#!/usr/bin/env bash

smart_update_package_version() {
    local package_line

    package_line=$(LC_ALL=C pacman -Q smart-update 2>/dev/null || true)
    if [[ "$package_line" =~ ^smart-update[[:space:]]+([^[:space:]]+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    printf '%s\n' 'unpackaged-development-tree'
}
