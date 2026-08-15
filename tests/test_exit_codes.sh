#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/exit_codes.sh
source "./lib/exit_codes.sh"

[[ "$EXIT_OK" -eq 0 ]]
[[ "$EXIT_GENERAL_ERROR" -eq 1 ]]
[[ "$EXIT_LOW_DISK_SPACE" -eq 10 ]]
[[ "$EXIT_PACKAGE_MANAGER_ACTIVE" -eq 11 ]]
[[ "$EXIT_STALE_PACMAN_LOCK" -eq 12 ]]
[[ "$EXIT_INSTANCE_ALREADY_RUNNING" -eq 20 ]]
[[ "$EXIT_CHECKUPDATES_FAILED" -eq 21 ]]
[[ "$EXIT_PACMAN_TRANSACTION_FAILED" -eq 26 ]]
[[ "$EXIT_INVALID_MODE" -eq 28 ]]
[[ "$EXIT_POLICY_BLOCK" -eq 29 ]]
[[ "$EXIT_INVALID_FINAL_DECISION" -eq 30 ]]
[[ "$EXIT_AUR_DISCOVERY_FAILED" -eq 31 ]]
[[ "$EXIT_AUR_UPDATE_FAILED" -eq 32 ]]
[[ "$EXIT_OFFICIAL_TRANSACTION_DRIFT" -eq 33 ]]
[[ "$EXIT_MANUAL_TRANSACTION_REQUIRED" -eq 34 ]]

[[ "$(exit_code_label 29)" == "POLICY_BLOCK" ]]
[[ "$(exit_code_label 26)" == "PACMAN_TRANSACTION_FAILED" ]]
[[ "$(exit_code_label 31)" == "AUR_DISCOVERY_FAILED" ]]
[[ "$(exit_code_label 32)" == "AUR_UPDATE_FAILED" ]]
[[ "$(exit_code_label 33)" == "OFFICIAL_TRANSACTION_DRIFT" ]]
[[ "$(exit_code_label 34)" == "MANUAL_TRANSACTION_REQUIRED" ]]
[[ "$(exit_code_label 255)" == "UNKNOWN" ]]

[[ -n "$(exit_code_description 0)" ]]
[[ -n "$(exit_code_description 29)" ]]
[[ "$(exit_code_description 255)" == "Code de sortie inconnu." ]]

printf 'Tous les tests des codes de sortie ont réussi.\n'
