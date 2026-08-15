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

Status: in development

Current phase:

- collect repository, package and version metadata directly from libalpm;
- allow only stable official candidates from `core`, `extra` and `multilib`;
- block testing, staging, unstable, VCS and explicit pre-release candidates;
- allow stable critical updates as `WARNING` only when explicitly configured;
- preserve the decision gate before every guarded installation.

Current AUR phase:

- isolated discovery and targeted installation of stable AUR packages via
  optional `yay`, without weakening official-package or decision-gate policies;
- non-root AUR build identity, unknown Foreign reporting and anti-TOCTOU checks;
- split official/AUR reporting with explicit installed, skipped and failed states.

## Later work

Future work must preserve the public exit-code contract and the rule that all
installation paths pass through the decision gate. Candidate areas include
additional reporting formats, notifications and carefully isolated decision
support features. Automatic override of security policies is out of scope.
