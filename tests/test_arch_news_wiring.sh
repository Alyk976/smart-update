#!/usr/bin/env bash

set -Eeuo pipefail

TARGET="./bin/smart-update"

if [[ ! -r "$TARGET" ]]; then
    printf "Erreur : programme principal introuvable.\n" >&2
    exit 1
fi

if grep -Fq "check_arch_news" "$TARGET"; then
    printf "Erreur : l’ancienne implémentation Arch News existe encore.\n" >&2
    exit 1
fi

assert_exact_line() {
    local expected_line="${1:-}"
    local count

    count=$(grep -F -c -x -- "$expected_line" "$TARGET" || true)

    if ((count != 1)); then
        printf 'Erreur : ligne attendue %q trouvée %d fois.\n' \
            "$expected_line" "$count" >&2
        exit 1
    fi
}

line_number() {
    local expected_line="${1:-}"

    grep -F -n -m 1 -x -- "$expected_line" "$TARGET" | cut -d: -f1
}

assert_exact_line \
    'readonly ARCH_NEWS_CONTEXT_MODULE="${LIB_DIR}/arch_news_context.sh"'

assert_exact_line \
    'readonly ARCH_NEWS_STATE_FILE="${STATE_DIR}/arch-news.last"'

assert_exact_line \
    'source "$ARCH_NEWS_CONTEXT_MODULE"'

assert_exact_line 'prepare_arch_news_context() {'
assert_exact_line 'persist_arch_news_context() {'

declare -a workflow_lines=(
    "    load_updates"
    "    prepare_arch_news_context"
    "    engine_load_policies"
    "    engine_run_policies"
    "    simulate_transaction"
    "    persist_arch_news_context"
    "    enforce_final_decision"
    "    install_updates"
    "    report_finalize"
)

declare -a workflow_positions=()
workflow_line=""

for workflow_line in "${workflow_lines[@]}"; do
    assert_exact_line "$workflow_line"
    workflow_positions+=("$(line_number "$workflow_line")")
done

for ((index = 1; index < ${#workflow_positions[@]}; index++)); do
    previous_index=$((index - 1))

    if ((workflow_positions[previous_index] >= workflow_positions[index])); then
        printf "Erreur : ordre du workflow principal invalide.\n" >&2
        exit 1
    fi
done

printf "Tous les tests du câblage Arch News ont réussi.\n"
