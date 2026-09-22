#!/usr/bin/env bash

# Optional delivery only; never participates in policy or transaction decisions.
telegram_send() (
    # Keep secrets out of inherited tracing and ERR diagnostics.
    set +x
    trap - ERR DEBUG RETURN
    local exit_code="${1:-1}" token_file token metadata message response
    token_file="${TELEGRAM_TOKEN_FILE:-/etc/smart-update/telegram.token}"

    command -v curl >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1
    [[ "${TELEGRAM_CHAT_ID:-}" =~ ^-?[0-9]+$ ]] || return 1
    [[ -f "$token_file" && ! -L "$token_file" && -r "$token_file" ]] || return 1
    metadata=$(stat -c '%u:%a:%s' -- "$token_file") || return 1
    [[ "$metadata" == "$EUID:600:"* ]] || return 1
    (( ${metadata##*:} <= 256 )) || return 1
    token=$(<"$token_file")
    [[ "$token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || return 1

    # Bounded, plain text summary. Do not send reports, package lists or stderr.
    printf -v message 'Smart Update\nMachine: %.128s\nMode: %.16s\nDecision: %.16s\nExit: %s (%.64s)\nOfficial: %.64s\nAUR: %.64s' \
        "${HOSTNAME:-unknown}" "${MODE:-unknown}" "${DECISION_FINAL:-UNKNOWN}" \
        "$exit_code" "$(exit_code_label "$exit_code")" \
        "${OFFICIAL_RESULT:-NOT_RUN}" "${AUR_RESULT:-NOT_RUN}"

    # -q must be first: ignore ~/.curlrc. Secret URL is passed over stdin,
    # never argv. No redirects, retries, response logging or disabled TLS checks.
    response=$(printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$token" |
        curl -q --config - --silent --fail --proto '=https' \
            --connect-timeout 5 --max-time 15 --max-filesize 65536 \
            --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
            --data-urlencode "text=${message}" 2>/dev/null) || return 1
    printf '%s' "$response" | jq -e '.ok == true' >/dev/null 2>&1
)

telegram_notify() {
    [[ "${TELEGRAM_ENABLED:-no}" == "yes" ]] || return 0
    if ! telegram_send "${1:-1}"; then
        logger_error 'Notification Telegram non envoyée ; résultat Smart Update inchangé.' || true
    fi
    return 0
}
