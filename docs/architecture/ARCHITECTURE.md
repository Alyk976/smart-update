# Smart Update architecture

## Overview

Smart Update is a deterministic policy engine around Arch Linux package
transactions. Collection modules prepare facts, policies evaluate those facts,
the decision module aggregates results, and a final gate prevents installation
whenever the verdict is `BLOCK`.

The default `audit` mode never installs packages. In `guarded` mode, Pacman may
run only after the complete analysis and the final decision gate.

## Runtime flow

```text
Load and validate configuration
    ↓
Check privileges, network, disk space and Pacman locking
    ↓
Collect available updates and Arch News context
    ↓
Prepare the libalpm transaction context
    ├── removals
    ├── replacements
    ├── additions
    └── repository/package/version metadata
    ↓
Derive new packages and dependencies from additions
    ↓
Run independent policies
    ↓
Aggregate ALLOW / WARNING / BLOCK
    ↓
Decision gate
    ↓
Audit only, guarded official installation, or controlled block
    ↓
Rediscover and verify stable AUR candidates
    ↓
Post-official yay/libalpm capability recheck
    ↓
Targeted yay installation with validated non-root build identity
    ↓
Finalize the report
```

## Components

- `bin/smart-update` orchestrates the workflow and enforces the decision gate.
- `lib/config.sh` loads and validates administrator configuration.
- `lib/system_checks.sh` performs preflight safety checks.
- `lib/arch_news*.sh` collects Arch News and maintains its persistent state.
- `tools/package-removals-helper/` prepares a transaction with libalpm and
  exposes removals, replacements, additions and candidate metadata without
  committing the transaction.
- `lib/package_removals.sh`, `lib/package_replacements.sh` and
  `lib/package_additions.sh` validate and normalize the helper output.
- `lib/package_candidates.sh` parses candidate metadata fail-closed, while
  `lib/stability.sh` provides deterministic, side-effect-free classification.
- `lib/aur_user.sh` resolves a non-root execution identity without guessing;
  `lib/aur_helper.sh` validates yay/libalpm before discovery and again after the
  official update; `lib/aur_context.sh`, `lib/aur_updates.sh` and
  `lib/aur_phase.sh` distinguish
  AUR from unknown Foreign packages, classify candidates, enforce anti-TOCTOU
  comparison and target only approved stable package names.
- `lib/policies/*.sh` implement deterministic policy decisions without causing
  installation or process termination.
- `lib/engine.sh` runs policies and records their results.
- `lib/decision.sh` aggregates policy results and controls installation access.
- `lib/logger.sh` writes the main and blocking-event logs.
- `lib/report.sh` creates reports, finalizes them once and deletes only reports
  older than the configured 90-day retention period.
- `lib/exit_codes.sh` defines the stable public exit-code contract.

## Transaction context

The native helper uses the prepared libalpm transaction as the authoritative
source. It reads `alpm_trans_get_remove()` for removals,
`alpm_trans_get_add()` for additions, and the libalpm replacement questions for
replacements. New packages and dependencies are obtained by comparing the
addition names with the installed package database; they are not inferred from
text output produced by a separate Pacman simulation.

For update eligibility, the same prepared addition objects expose their owning
sync database, package name and version as `repository|package|version`.
Only stable candidates from `core`, `extra` and `multilib` are currently
eligible. Testing, staging, unstable, third-party, VCS and explicit pre-release
candidates fail closed before the decision gate. The AUR phase remains isolated
from this official-repository metadata boundary.

## Policy gate and execution capability gate

The policy gate and the execution capability gate answer different questions.
The policy gate decides whether the analyzed changes are acceptable to the
administrator. The execution capability gate decides whether Pacman's CLI can
apply those changes non-interactively without answering a package-manager
choice globally.

The read-only libalpm helper exposes transaction questions as strict records:

```text
TYPE|field1|field2|field3|field4
```

An empty question set is `AUTOMATIC`. Conflict removals, replacements, provider
selection, ignored packages, unresolved-target removal, corrupted packages,
key import and unknown question types are `MANUAL_REQUIRED`. A normal new
dependency is not manual by itself; its policy still decides whether it is
allowed. A manual official transaction defers AUR installation because the
required official upgrade has not completed.

Immediately before an automatic guarded installation, Smart Update rebuilds
the read-only transaction context from the same checkupdates database and
compares updates, repositories, candidate versions, additions, removals,
replacements and questions with the approved snapshot. Drift aborts before
Pacman starts. Pacman remains the installation frontend and runs `-Syu` with a
conservative question mask: ignored packages, replacements, corrupted-package
deletion and key import are refused; conflict removals and unresolved-target
removal retain their safe negative defaults. Provider selection cannot be
refused through Pacman's question mask, which is why transactions already
known to require it are manual.

This check is deliberately not described as atomic. A small TOCTOU window
remains between the final helper comparison and Pacman's acquisition of its
database lock. Pacman also refreshes the live sync databases as part of `-Syu`
and remains the final authority. Any unexpected question is refused rather
than accepted globally; a subsequent run performs a fresh analysis.

## Filesystem and services

Immutable application files live under `/usr`, administrator configuration
under `/etc/smart-update`, persistent state under `/var/lib/smart-update`, and
logs and reports under `/var/log/smart-update`. systemd-tmpfiles owns creation
of the runtime directories in the Arch package.

The oneshot `smart-update.service` accepts exit codes `0`, `29` and `34` as
controlled outcomes. Exit code `31` and all other non-zero codes remain
failures. `smart-update.timer` schedules daily execution. The optional
`/etc/logrotate.d/smart-update` configuration rotates only the two append-only
logs; report retention remains part of Smart Update itself.

## Security invariants

- No policy installs packages or bypasses the central decision module.
- A `BLOCK` always prevents `pacman -Syu`.
- Invalid or missing transaction context fails closed.
- Stable critical packages produce `WARNING` and remain installable by default.
  An administrator may set `ALLOW_CRITICAL_UPDATES="no"` for an
  ultra-conservative `BLOCK`; the stability policy always takes precedence, so
  an unstable critical candidate remains blocked.
- Configuration, state, logs and reports use restrictive permissions.
- Smart Update never removes a Pacman lock automatically.
- No automatic reboot, snapshot or forced overwrite is performed.
- Every controlled run finalizes its report when a report exists.
- Read-only yay commands run as the validated non-root AUR identity. The
  current installation path still launches `yay -S` from the root orchestrator
  with `SUDO_USER`, `SUDO_UID`, `SUDO_GID` and `HOME` derived from that account,
  and relies on yay to drop its build commands. This is not equivalent to a
  fully separated non-root builder and minimal root installer. Timer-based AUR
  automation must not be described as fully hardened until that split exists.
- `AUR_USER=auto` is valid only when a manual sudo invocation supplies a
  trustworthy non-root `SUDO_USER`. An automated service with AUR enabled
  requires an explicit `AUR_USER`; resolution failure returns `31` before any
  official package transaction can start.
- Smart Update never creates sudoers rules or enables `--devel`/`--sudoloop`.
- A yay/libalpm failure after official success defers the AUR phase, produces a
  partial non-zero result and never triggers an automatic Pacman rollback.
