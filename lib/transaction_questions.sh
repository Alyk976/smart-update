#!/usr/bin/env bash
# shellcheck disable=SC2034

TRANSACTION_QUESTIONS_ERROR=""
OFFICIAL_EXECUTION_CAPABILITY="UNKNOWN"
declare -a TRANSACTION_QUESTIONS=()

transaction_questions_collect() {
    local helper="${1:-}" output error_file error_output status line
    local type field1 field2 field3 field4 remainder field separators

    TRANSACTION_QUESTIONS_ERROR=""
    TRANSACTION_QUESTIONS=()
    OFFICIAL_EXECUTION_CAPABILITY="UNKNOWN"
    error_file=$(mktemp)
    if output=$("$helper" --questions 2>"$error_file"); then status=0; else status=$?; fi
    error_output=$(<"$error_file")
    rm -f "$error_file"
    if ((status != 0)); then
        TRANSACTION_QUESTIONS_ERROR="Question collector failed (${status}): ${error_output}"
        OFFICIAL_EXECUTION_CAPABILITY="MANUAL_REQUIRED"
        return 1
    fi

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        separators=${line//[^|]/}
        if ((${#separators} != 4)); then
            TRANSACTION_QUESTIONS=()
            TRANSACTION_QUESTIONS_ERROR="Invalid transaction question: ${line}"
            OFFICIAL_EXECUTION_CAPABILITY="MANUAL_REQUIRED"
            return 1
        fi
        IFS='|' read -r type field1 field2 field3 field4 remainder <<<"$line"
        if [[ -n "${remainder:-}" || ! "$type" =~ ^(CONFLICT_PKG|REPLACE_PKG|SELECT_PROVIDER|INSTALL_IGNOREPKG|REMOVE_PKGS|CORRUPTED_PKG|IMPORT_KEY|UNKNOWN)$ ]]; then
            TRANSACTION_QUESTIONS=()
            TRANSACTION_QUESTIONS_ERROR="Invalid transaction question: ${line}"
            OFFICIAL_EXECUTION_CAPABILITY="MANUAL_REQUIRED"
            return 1
        fi
        for field in "$field1" "$field2" "$field3" "$field4"; do
            if [[ "$field" =~ [[:cntrl:]\|] ]]; then
                TRANSACTION_QUESTIONS=()
                TRANSACTION_QUESTIONS_ERROR="Invalid transaction question field."
                OFFICIAL_EXECUTION_CAPABILITY="MANUAL_REQUIRED"
                return 1
            fi
        done
        TRANSACTION_QUESTIONS+=("$line")
    done <<<"$output"

    if ((${#TRANSACTION_QUESTIONS[@]} > 0)); then
        OFFICIAL_EXECUTION_CAPABILITY="MANUAL_REQUIRED"
    else
        OFFICIAL_EXECUTION_CAPABILITY="AUTOMATIC"
    fi
}

transaction_snapshot() {
    local item index
    for item in "${UPDATE_LINES[@]}"; do printf 'U|%s\n' "$item"; done
    for item in "${PACKAGE_ADDITIONS[@]}"; do printf 'A|%s\n' "$item"; done
    for item in "${PACKAGE_REMOVALS[@]}"; do printf 'R|%s\n' "$item"; done
    for item in "${PACKAGE_REPLACEMENTS[@]}"; do printf 'P|%s\n' "$item"; done
    for index in "${!PACKAGE_CANDIDATE_NAMES[@]}"; do
        printf 'C|%s|%s|%s\n' "${PACKAGE_CANDIDATE_REPOS[$index]}" \
            "${PACKAGE_CANDIDATE_NAMES[$index]}" \
            "${PACKAGE_CANDIDATE_VERSIONS[$index]}"
    done
    for item in "${TRANSACTION_QUESTIONS[@]}"; do printf 'Q|%s\n' "$item"; done
}
