#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

LOG_FILE="$TEST_DIR/smart-update.log"
BLOCKED_LOG="$TEST_DIR/blocked.log"
export DEBUG="yes"


# shellcheck source=lib/logger.sh
source "./lib/logger.sh"

logger_info "Test information"
logger_warning "Test avertissement"
logger_error "Test erreur"
logger_success "Test succès"
logger_debug "Test debug"
logger_blocked "Test blocage"

grep -q '\[INFO\] Test information' "$LOG_FILE"
grep -q '\[WARNING\] Test avertissement' "$LOG_FILE"
grep -q '\[ERROR\] Test erreur' "$LOG_FILE"
grep -q '\[SUCCESS\] Test succès' "$LOG_FILE"
grep -q '\[DEBUG\] Test debug' "$LOG_FILE"
grep -q '\[BLOCKED\] Test blocage' "$LOG_FILE"
grep -q 'Test blocage' "$BLOCKED_LOG"

printf 'Tous les tests du logger ont réussi.\n'
