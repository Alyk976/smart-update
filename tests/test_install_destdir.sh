#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT

TEST_DIR=$(mktemp -d)
ROOTFS="${TEST_DIR}/root"

cleanup() {
    make -C "$PROJECT_ROOT" clean >/dev/null 2>&1 || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

make -C "$PROJECT_ROOT" DESTDIR="$ROOTFS" install >/dev/null

assert_file() {
    local path="${1:?}"
    [[ -f "$ROOTFS$path" ]] || {
        printf 'Erreur : fichier installé absent : %s\n' "$path" >&2
        exit 1
    }
}

assert_dir() {
    local path="${1:?}"
    [[ -d "$ROOTFS$path" ]] || {
        printf 'Erreur : répertoire installé absent : %s\n' "$path" >&2
        exit 1
    }
}

assert_mode() {
    local path="${1:?}"
    local expected="${2:?}"
    local actual

    actual=$(stat -c '%a' "$ROOTFS$path")
    [[ "$actual" == "$expected" ]] || {
        printf 'Erreur : mode %s pour %s, attendu %s.\n' \
            "$actual" "$path" "$expected" >&2
        exit 1
    }
}

assert_same_file() {
    local source_path="${1:?}"
    local installed_path="${2:?}"

    cmp -s "$PROJECT_ROOT/$source_path" "$ROOTFS$installed_path" || {
        printf 'Erreur : contenu installé différent pour %s.\n' \
            "$installed_path" >&2
        exit 1
    }
}

assert_file /usr/bin/smart-update
assert_file /usr/lib/smart-update/arch_news.sh
assert_file /usr/lib/smart-update/arch_news_context.sh
assert_file /usr/lib/smart-update/arch_news_state.sh
assert_file /usr/lib/smart-update/config.sh
assert_file /usr/lib/smart-update/engine.sh
assert_file /usr/lib/smart-update/exit_codes.sh
assert_file /usr/lib/smart-update/package_additions.sh
assert_file /usr/lib/smart-update/package_candidates.sh
assert_file /usr/lib/smart-update/stability.sh
assert_file /usr/lib/smart-update/package-removals-helper
assert_file /usr/lib/smart-update/policies/10_update_count.sh
assert_file /usr/lib/smart-update/policies/15_stable_updates.sh
assert_file /usr/lib/smart-update/policies/80_new_dependencies.sh
assert_file /usr/lib/systemd/system/smart-update.service
assert_file /usr/lib/systemd/system/smart-update.timer
assert_file /etc/smart-update/smart-update.conf
assert_file /etc/smart-update/critical-packages.conf
assert_file /etc/logrotate.d/smart-update
assert_file /usr/share/licenses/smart-update/LICENSE
assert_file /usr/share/licenses/smart-update/NOTICE

assert_dir /usr/lib/smart-update
assert_dir /usr/lib/smart-update/policies
assert_dir /usr/lib/systemd/system
assert_dir /etc/smart-update
assert_dir /etc/logrotate.d
assert_dir /var/lib/smart-update
assert_dir /var/log/smart-update
assert_dir /var/log/smart-update/reports

assert_mode /usr/bin/smart-update 755
assert_mode /usr/lib/smart-update 755
assert_mode /usr/lib/smart-update/arch_news.sh 644
assert_mode /usr/lib/smart-update/arch_news_context.sh 644
assert_mode /usr/lib/smart-update/arch_news_state.sh 644
assert_mode /usr/lib/smart-update/config.sh 644
assert_mode /usr/lib/smart-update/engine.sh 644
assert_mode /usr/lib/smart-update/exit_codes.sh 644
assert_mode /usr/lib/smart-update/package_additions.sh 644
assert_mode /usr/lib/smart-update/package_candidates.sh 644
assert_mode /usr/lib/smart-update/stability.sh 644
assert_mode /usr/lib/smart-update/policies 755
assert_mode /usr/lib/smart-update/policies/10_update_count.sh 644
assert_mode /usr/lib/smart-update/policies/15_stable_updates.sh 644
assert_mode /usr/lib/smart-update/policies/80_new_dependencies.sh 644
assert_mode /usr/lib/smart-update/package-removals-helper 755
assert_mode /usr/lib/systemd/system/smart-update.service 644
assert_mode /usr/lib/systemd/system/smart-update.timer 644
assert_mode /etc/smart-update 750
assert_mode /etc/smart-update/smart-update.conf 640
assert_mode /etc/smart-update/critical-packages.conf 640
assert_mode /etc/logrotate.d/smart-update 644
assert_mode /usr/share/licenses/smart-update/LICENSE 644
assert_mode /usr/share/licenses/smart-update/NOTICE 644
assert_mode /var/lib/smart-update 750
assert_mode /var/log/smart-update 750
assert_mode /var/log/smart-update/reports 750

assert_same_file bin/smart-update /usr/bin/smart-update
assert_same_file lib/arch_news.sh /usr/lib/smart-update/arch_news.sh
assert_same_file lib/arch_news_context.sh /usr/lib/smart-update/arch_news_context.sh
assert_same_file lib/arch_news_state.sh /usr/lib/smart-update/arch_news_state.sh
assert_same_file lib/config.sh /usr/lib/smart-update/config.sh
assert_same_file lib/engine.sh /usr/lib/smart-update/engine.sh
assert_same_file lib/exit_codes.sh /usr/lib/smart-update/exit_codes.sh
assert_same_file lib/package_additions.sh /usr/lib/smart-update/package_additions.sh
assert_same_file lib/package_candidates.sh /usr/lib/smart-update/package_candidates.sh
assert_same_file lib/stability.sh /usr/lib/smart-update/stability.sh
assert_same_file lib/policies/10_update_count.sh \
    /usr/lib/smart-update/policies/10_update_count.sh
assert_same_file lib/policies/15_stable_updates.sh \
    /usr/lib/smart-update/policies/15_stable_updates.sh
assert_same_file lib/policies/80_new_dependencies.sh \
    /usr/lib/smart-update/policies/80_new_dependencies.sh
assert_same_file systemd/smart-update.service \
    /usr/lib/systemd/system/smart-update.service
assert_same_file systemd/smart-update.timer \
    /usr/lib/systemd/system/smart-update.timer
assert_same_file config/smart-update.conf \
    /etc/smart-update/smart-update.conf
grep -F -x -q 'ALLOW_CRITICAL_UPDATES="yes"' \
    "$ROOTFS/etc/smart-update/smart-update.conf"
assert_same_file config/critical-packages.conf \
    /etc/smart-update/critical-packages.conf
assert_same_file packaging/smart-update.logrotate \
    /etc/logrotate.d/smart-update
assert_same_file LICENSE /usr/share/licenses/smart-update/LICENSE
assert_same_file NOTICE /usr/share/licenses/smart-update/NOTICE

[[ -s "$ROOTFS/usr/lib/smart-update/package-removals-helper" ]]
[[ -x "$ROOTFS/usr/lib/smart-update/package-removals-helper" ]]

printf 'sentinel-smart-update=true\n' \
    >"$ROOTFS/etc/smart-update/smart-update.conf"
printf 'sentinel-critical-packages=true\n' \
    >"$ROOTFS/etc/smart-update/critical-packages.conf"

make -C "$PROJECT_ROOT" DESTDIR="$ROOTFS" install >/dev/null

grep -Fxq 'sentinel-smart-update=true' \
    "$ROOTFS/etc/smart-update/smart-update.conf"
grep -Fxq 'sentinel-critical-packages=true' \
    "$ROOTFS/etc/smart-update/critical-packages.conf"

printf "Tous les tests d’installation DESTDIR ont réussi.\n"
