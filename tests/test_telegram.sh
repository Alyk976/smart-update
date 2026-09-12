#!/usr/bin/env bash
# shellcheck disable=SC2034
set -Eeuo pipefail
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
# shellcheck source=lib/telegram.sh
source ./lib/telegram.sh
# shellcheck source=lib/exit_codes.sh
source ./lib/exit_codes.sh
logger_error() { printf '%s\n' "$*" >> "$TEST_DIR/errors"; }
# Simulated API only: assert request security and capture delivery.
curl() {
    [[ "$1" == '-q' ]]
    printf '%s\n' "$@" > "$TEST_DIR/args"
    cat > "$TEST_DIR/request"
    printf '.\n' >> "$TEST_DIR/calls"
    printf '%s\n' "${API_RESPONSE:-{\"ok\":true}}"
    return "${CURL_STATUS:-0}"
}
# Exercise the actual JSON parser, not a mock.
command -v jq >/dev/null
telegram_notify 0
[[ ! -e "$TEST_DIR/calls" ]]
TELEGRAM_ENABLED=yes
TELEGRAM_CHAT_ID=12345
TELEGRAM_TOKEN_FILE="$TEST_DIR/token"
printf '123456:TEST_SECRET\n' > "$TELEGRAM_TOKEN_FILE"
chmod 600 "$TELEGRAM_TOKEN_FILE"
MODE=audit
DECISION_FINAL=BLOCK
telegram_notify 29
[[ $(wc -l < "$TEST_DIR/calls") == 1 ]]
grep -q 'Decision: BLOCK' "$TEST_DIR/args"
grep -q '29 (POLICY_BLOCK)' "$TEST_DIR/args"
if grep -q TEST_SECRET "$TEST_DIR/args"; then exit 1; fi
grep -q 'bot123456:TEST_SECRET/sendMessage' "$TEST_DIR/request"
[[ ! -e "$TEST_DIR/errors" ]]
# Both transport and API failure remain non-blocking and redact responses.
CURL_STATUS=28
telegram_notify 26
CURL_STATUS=0
API_RESPONSE='{"ok":false,"description":"TEST_SECRET"}'
telegram_notify 26
API_RESPONSE='not JSON'
telegram_notify 26
[[ $(wc -l < "$TEST_DIR/errors") == 3 ]]
if grep -q TEST_SECRET "$TEST_DIR/errors"; then exit 1; fi
# Permissions, malformed tokens and bad destination cause no network calls.
count=$(wc -l < "$TEST_DIR/calls")
chmod 644 "$TELEGRAM_TOKEN_FILE"
telegram_notify 0
chmod 600 "$TELEGRAM_TOKEN_FILE"
printf '123:bad"\nurl="https://example.com\n' > "$TELEGRAM_TOKEN_FILE"
telegram_notify 0
printf '123456:TEST_SECRET\n' > "$TELEGRAM_TOKEN_FILE"
TELEGRAM_CHAT_ID=bot_username
telegram_notify 0
[[ $(wc -l < "$TEST_DIR/calls") == "$count" ]]
TELEGRAM_CHAT_ID=-12345
API_RESPONSE='{"ok":true}'
# Inherited xtrace cannot disclose the token.
( set -x; telegram_notify 0 ) 2> "$TEST_DIR/trace"
if grep -q TEST_SECRET "$TEST_DIR/trace"; then exit 1; fi
# Run the production EXIT handler and preserve its result even when delivery fails.
eval "$(sed -n '/^finalize_report_on_exit() {/,/^}/p' bin/smart-update)"
REPORT_FILE="$TEST_DIR/report"
REPORT_FINALIZED=no
touch "$REPORT_FILE"
report_finalize() { printf '%s\n' "$1" >> "$REPORT_FILE"; }
CURL_STATUS=28
for expected in 0 26 29 34; do
    count=$(wc -l < "$TEST_DIR/calls")
    actual=0
    ( trap finalize_report_on_exit EXIT; exit "$expected" ) || actual=$?
    [[ "$actual" == "$expected" ]]
    [[ $(wc -l < "$TEST_DIR/calls") == $((count + 1)) ]]
done
# A report finalized by a controlled exit must not be appended again.
REPORT_FINALIZED=yes
report_lines=$(wc -l < "$REPORT_FILE")
( trap finalize_report_on_exit EXIT; exit 29 ) || [[ "$?" == 29 ]]
[[ $(wc -l < "$REPORT_FILE") == "$report_lines" ]]
printf 'Telegram: delivery, redaction and exit preservation passed.\n'
