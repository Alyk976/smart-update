#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=lib/stability.sh
source "./lib/stability.sh"

assert_stable() {
    stability_candidate_is_stable "$1" "$2" "$3" || {
        printf 'Erreur : candidat stable refusé : %s/%s/%s (%s).\n' \
            "$1" "$2" "$3" "$STABILITY_REASON" >&2
        exit 1
    }
}

assert_unstable() {
    if stability_candidate_is_stable "$1" "$2" "$3"; then
        printf 'Erreur : candidat instable accepté : %s/%s/%s.\n' \
            "$1" "$2" "$3" >&2
        exit 1
    fi
    [[ -n "$STABILITY_REASON" ]]
}

assert_stable core linux 1.2.3-4
assert_stable extra firefox 133.0-1
assert_stable multilib lib32-glibc 2.40+r123-1
assert_stable extra foo-bin 1.0.0-1
assert_unstable core-testing linux 6.13.0-1
assert_unstable extra-testing firefox 134.0-1
assert_unstable gnome-unstable mutter 48.0-1
assert_unstable core-staging glibc 2.41-1
assert_unstable custom-repo package 1.0.0-1
assert_unstable core package 2.0.0-beta1
assert_unstable extra package 5.0.0-rc2
assert_unstable multilib package 1.0.0-alpha
assert_unstable core package 1.0.0-dev.2
assert_unstable core package 1.0.0-nightly-20260815
assert_unstable core package 1.0.0-snapshot.1
assert_unstable extra foo-git 1.0.0.r123-1

run_policy() {
    unset -f policy_run 2>/dev/null || true
    # shellcheck source=lib/policies/15_stable_updates.sh
    source "./lib/policies/15_stable_updates.sh"
    policy_run
}

PACKAGE_CANDIDATES_ERROR=""
PACKAGE_CANDIDATE_REPOS=(core extra multilib)
PACKAGE_CANDIDATE_NAMES=(linux firefox lib32-glibc)
PACKAGE_CANDIDATE_VERSIONS=(1.2.3-4 133.0-1 2.40+r123-1)
run_policy
[[ "$POLICY_RESULT" == "ALLOW" ]]

PACKAGE_CANDIDATE_REPOS=(core core-testing)
PACKAGE_CANDIDATE_NAMES=(linux candidate)
PACKAGE_CANDIDATE_VERSIONS=(1.2.3-4 2.0.0-beta1)
run_policy
[[ "$POLICY_RESULT" == "BLOCK" ]]
((${#POLICY_DETAILS[@]} == 1))
[[ "${POLICY_DETAILS[0]}" == core-testing/candidate/2.0.0-beta1\ :* ]]

PACKAGE_CANDIDATE_REPOS=()
PACKAGE_CANDIDATE_NAMES=()
PACKAGE_CANDIDATE_VERSIONS=()
PACKAGE_CANDIDATES_ERROR="Le helper libalpm a échoué."
run_policy
[[ "$POLICY_RESULT" == "BLOCK" ]]
[[ "${POLICY_DETAILS[0]}" == "$PACKAGE_CANDIDATES_ERROR" ]]

printf 'Tous les tests de stabilité des mises à jour ont réussi.\n'
