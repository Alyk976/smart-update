# Roadmap

## v1.0.0 — First stable release

Status: released

Delivered:

- deterministic policy engine and central decision gate;
- audit and guarded modes;
- Arch News collection and persistent state;
- critical-update and foreign-package policies;
- libalpm transaction analysis for removals, replacements and additions;
- new-package and dependency detection;
- structured logs, final reports and 90-day report retention;
- optional logrotate integration;
- systemd service, timer and tmpfiles integration;
- native Arch package metadata and installation layout;
- 33 automated tests plus package and live-system validation.

## v1.1.0 — Update eligibility and extended sources

Status: **released**

Delivered:

- fail-closed repository/package/version eligibility checks from libalpm;
- stable official candidates from `core`, `extra` and `multilib` only;
- blocking of testing, staging, unstable, VCS and explicit pre-release candidates;
- policy-controlled stable critical updates as `WARNING` when permitted;
- transaction-question analysis and `MANUAL_TRANSACTION_REQUIRED` (`34`) for
  Pacman choices that Smart Update deliberately refuses to automate;
- official transaction drift detection before guarded execution (`33`) ;
- isolated discovery and targeted installation of stable AUR packages through
  optional `yay` support;
- validated non-root AUR identity and fail-closed identity handling (`31`) ;
- post-official `yay`/libalpm capability recheck;
- unknown Foreign package reporting without automatic modification;
- split official/AUR reporting with explicit installed, skipped and failed states;
- systemd handling of controlled outcomes `29` and `34`;
- 46 automated tests;
- package build and protected live-system validation;
- successful guarded-mode execution of a large real Arch Linux update transaction.

AUR automation remains disabled by default. The current v1.1.0 AUR installation
path is documented as not fully hardened because non-root build responsibilities
and minimal root installation responsibilities are not yet split into separate
components.

## v1.2.0 — Next development line

Status: planned

Candidate areas include:

- clearer runtime/status reporting for administrators;
- improved operational summaries and notifications;
- further privilege separation for the AUR build/install path;
- additional validation and reporting formats.

The exact v1.2.0 scope will be decided before implementation. New work must
preserve the public exit-code contract, deterministic decision model and the
rule that every installation path passes through the safety gates.

## Stable maintenance

The `v1.1.x` line is reserved for necessary bug fixes. Existing release tags are
immutable and must not be moved after publication or package construction.

Automatic override of security policies remains out of scope.
