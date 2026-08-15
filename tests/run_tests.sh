#!/usr/bin/env bash

set -Eeuo pipefail

start_time=$(date +%s%3N)

total=0
passed=0
failed=0

printf '====================================================\n'
printf '           Smart Update - Test Suite\n'
printf '====================================================\n\n'

for test in tests/test_*.sh; do
    ((total += 1))

    if bash "$test" >/dev/null; then
        printf '[PASS] %s\n' "$(basename "$test")"
        ((passed += 1))
    else
        printf '[FAIL] %s\n' "$(basename "$test")"
        ((failed += 1))
    fi
done

end_time=$(date +%s%3N)
duration_ms=$((end_time - start_time))

printf '\n----------------------------------------------------\n'
printf 'Tests exécutés : %d\n' "$total"
printf 'Réussis        : %d\n' "$passed"
printf 'Échecs         : %d\n' "$failed"
printf 'Durée          : %d ms\n' "$duration_ms"
printf '====================================================\n'

if ((failed == 0)); then
    printf '✓ Tous les tests ont réussi.\n'
    exit 0
fi

printf '✗ Des tests ont échoué.\n'
exit 1
