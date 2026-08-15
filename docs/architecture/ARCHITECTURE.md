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
    └── additions
    ↓
Derive new packages and dependencies from additions
    ↓
Run independent policies
    ↓
Aggregate ALLOW / WARNING / BLOCK
    ↓
Decision gate
    ↓
Audit only, guarded installation, or controlled block
    ↓
Finalize the report
```

## Components

- `bin/smart-update` orchestrates the workflow and enforces the decision gate.
- `lib/config.sh` loads and validates administrator configuration.
- `lib/system_checks.sh` performs preflight safety checks.
- `lib/arch_news*.sh` collects Arch News and maintains its persistent state.
- `tools/package-removals-helper/` prepares a transaction with libalpm and
  exposes removals, replacements and additions.
- `lib/package_removals.sh`, `lib/package_replacements.sh` and
  `lib/package_additions.sh` validate and normalize the helper output.
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

## Filesystem and services

Immutable application files live under `/usr`, administrator configuration
under `/etc/smart-update`, persistent state under `/var/lib/smart-update`, and
logs and reports under `/var/log/smart-update`. systemd-tmpfiles owns creation
of the runtime directories in the Arch package.

The oneshot `smart-update.service` accepts exit codes `0` and `29` as controlled
outcomes. `smart-update.timer` schedules daily execution. The optional
`/etc/logrotate.d/smart-update` configuration rotates only the two append-only
logs; report retention remains part of Smart Update itself.

## Security invariants

- No policy installs packages or bypasses the central decision module.
- A `BLOCK` always prevents `pacman -Syu`.
- Invalid or missing transaction context fails closed.
- Configuration, state, logs and reports use restrictive permissions.
- Smart Update never removes a Pacman lock automatically.
- No automatic reboot, snapshot or forced overwrite is performed.
- Every controlled run finalizes its report when a report exists.
