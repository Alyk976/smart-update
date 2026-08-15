#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT

LOGROTATE_CONFIG="${PROJECT_ROOT}/packaging/smart-update.logrotate"
MAKEFILE="${PROJECT_ROOT}/Makefile"
PKGBUILD_FILE="${PROJECT_ROOT}/PKGBUILD"
readonly LOGROTATE_CONFIG MAKEFILE PKGBUILD_FILE

fail() {
    printf 'Erreur : %s\n' "$*" >&2
    exit 1
}

assert_occurs_once() {
    local expected="${1:?}"
    local count

    count=$(awk -v expected="$expected" '
        {
            line = $0
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line == expected) {
                count++
            }
        }
        END { print count + 0 }
    ' "$LOGROTATE_CONFIG")

    [[ "$count" -eq 1 ]] ||
        fail "la directive '${expected}' doit être présente exactement une fois."
}

[[ -r "$LOGROTATE_CONFIG" ]] ||
    fail "configuration logrotate absente ou illisible."

for log_path in \
    /var/log/smart-update/smart-update.log \
    /var/log/smart-update/blocked.log; do
    count=$(grep -Fo -- "$log_path" "$LOGROTATE_CONFIG" | wc -l)
    [[ "$count" -eq 1 ]] ||
        fail "le chemin '${log_path}' doit être présent exactement une fois."
done

for directive in \
    weekly \
    'rotate 8' \
    compress \
    delaycompress \
    missingok \
    notifempty \
    'create 0640 root root'; do
    assert_occurs_once "$directive"
done

if grep -Fq -- '/var/log/smart-update/reports' "$LOGROTATE_CONFIG"; then
    fail "la configuration logrotate ne doit pas gérer le répertoire des rapports."
fi

if grep -Fq -- 'report-*.txt' "$LOGROTATE_CONFIG"; then
    fail "la configuration logrotate ne doit pas gérer les fichiers de rapport."
fi

grep -Fq -- 'packaging/smart-update.logrotate' "$MAKEFILE" ||
    fail "la source logrotate n'est pas installée par le Makefile."
grep -Fq -- "\$(DESTDIR)\$(LOGROTATEDIR)/smart-update" "$MAKEFILE" ||
    fail "la destination logrotate est absente du Makefile."

optdepends_line=$(grep -E '^optdepends=' "$PKGBUILD_FILE")
[[ "$optdepends_line" == *"'logrotate:"* ]] ||
    fail "logrotate doit être déclaré dans optdepends."

depends_line=$(grep -E '^depends=' "$PKGBUILD_FILE")
dependency_pattern="'logrotate([<>=][^']*)?'"
[[ ! "$depends_line" =~ $dependency_pattern ]] ||
    fail "logrotate ne doit pas être déclaré dans depends."

if command -v logrotate >/dev/null 2>&1; then
    logrotate --debug "$LOGROTATE_CONFIG" >/dev/null
fi

printf 'Tous les tests logrotate ont réussi.\n'
