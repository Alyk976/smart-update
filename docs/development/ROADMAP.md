# Roadmap

## v1.0.0 — First stable release

Status: release preparation complete

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

## After v1.0.0

Future work must preserve the public exit-code contract and the rule that all
installation paths pass through the decision gate. Candidate areas include
additional reporting formats, notifications and carefully isolated decision
support features. Automatic override of security policies is out of scope.
