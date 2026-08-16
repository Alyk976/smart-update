#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT

SERVICE="$PROJECT_ROOT/systemd/smart-update.service"
TIMER="$PROJECT_ROOT/systemd/smart-update.timer"

for unit in "$SERVICE" "$TIMER"; do
    [[ -r "$unit" ]] || {
        printf 'Erreur : unité systemd absente : %s\n' "$unit" >&2
        exit 1
    }
done

assert_line() {
    local file="${1:?}"
    local expected="${2:?}"

    grep -F -x -q -- "$expected" "$file" || {
        printf 'Erreur : directive absente dans %s : %s\n' \
            "$file" "$expected" >&2
        exit 1
    }
}

assert_line "$SERVICE" 'Type=oneshot'
assert_line "$SERVICE" 'ExecStart=/usr/bin/smart-update'
assert_line "$SERVICE" 'SuccessExitStatus=29 34'
assert_line "$SERVICE" 'User=root'
assert_line "$SERVICE" 'Group=root'
assert_line "$SERVICE" 'UMask=0027'
assert_line "$SERVICE" 'Wants=network-online.target'
assert_line "$SERVICE" 'After=network-online.target'

if grep -Eq '^SuccessExitStatus=([^[:space:]]+[[:space:]]+)*31([[:space:]]|$)' "$SERVICE"; then
    printf 'Erreur : AUR_DISCOVERY_FAILED ne doit pas être un succès systemd.\n' >&2
    exit 1
fi

if grep -Eq '^(Environment|PassEnvironment)=.*SUDO_USER' "$SERVICE"; then
    printf 'Erreur : le service ne doit pas fabriquer un contexte sudo.\n' >&2
    exit 1
fi

assert_line "$TIMER" 'OnActiveSec=5min'
assert_line "$TIMER" 'OnUnitActiveSec=1d'
assert_line "$TIMER" 'Persistent=true'
assert_line "$TIMER" 'WantedBy=timers.target'

if grep -F -x -q -- 'OnBootSec=5min' "$TIMER"; then
    printf 'Erreur : le timer ne doit plus dépendre de OnBootSec=5min.\n' >&2
    exit 1
fi

if command -v systemd-analyze >/dev/null 2>&1; then
    systemd-analyze verify "$SERVICE" "$TIMER" >/dev/null
fi

printf 'Tous les tests des unités systemd ont réussi.\n'
