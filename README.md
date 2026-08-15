# Smart Update

> **Think first. Update safely.**

Smart Update is a deterministic, policy-driven update decision engine for Arch Linux.

Instead of blindly running `pacman -Syu`, Smart Update inspects the system, prepares transaction context, evaluates safety policies and produces a final decision:

- `ALLOW`: installation may continue in guarded mode;
- `WARNING`: installation may continue, but administrator review is recommended;
- `BLOCK`: installation is forbidden.

The core principle is simple:

> **Policies decide. The administrator remains in control.**

---

## Trust by design

Smart Update is an update tool first. Analysis and policy evaluation exist to
make installation safer, not to replace installation. Its operating principle
is:

> **Analyze → Decide → Update**

Smart Update is designed to:

- install stable Arch Linux updates;
- install stable security updates;
- update stable AUR packages through optional `yay` support in v1.1.0;
- refuse alpha, beta, RC, development, nightly, snapshot and VCS updates;
- inspect removals, replacements and new dependencies;
- never silently bypass safety policies;
- stop safely when a transaction cannot be understood;
- produce a report explaining what was installed, blocked or skipped.

A Smart Update user should not have to wonder whether the tool will install a
beta, silently ignore legitimate stable updates, bypass safety rules, or block
normal stable updates forever. This design reduces avoidable risk while keeping
the administrator responsible for system policy and operational review.

Smart Update v1.1.0 automatically installs ordinary stable transactions.
Transactions requiring package-manager choices such as conflict removals,
replacements or provider selection are analyzed but deferred for manual
execution. Smart Update does not globally answer Pacman transaction questions.
If the transaction changes between analysis and the final pre-installation
check, Smart Update aborts and analyzes again instead of guessing.

Smart Update verifies that the configured AUR helper is operational again
after the official system upgrade before starting any AUR installation. If an
official pacman/libalpm update makes yay temporarily unavailable, Smart Update
stops the AUR phase and reports a partial result instead of guessing or forcing
the installation.

---

## Current status

Smart Update v1.0.0 is the first stable release of the project.

Development toward v1.1.0 adds fail-closed eligibility checks for stable
official updates, policy-controlled handling of critical packages, and targeted
stable AUR updates through optional `yay` integration.

The following areas are implemented and tested:

- modular policy engine;
- deterministic `ALLOW` / `WARNING` / `BLOCK` aggregation;
- final decision gate before installation;
- Arch Linux news tracking;
- critical-package detection;
- foreign/AUR package reporting;
- package-removal detection through libalpm;
- package-replacement detection through libalpm;
- package-addition detection through libalpm;
- forced-overwrite guard;
- new dependency detection;
- audit and guarded operating modes;
- structured logs and execution reports;
- optional weekly log rotation;
- centralized exit-code contract;
- native system installation layout;
- systemd service and daily timer;
- automated installation tests using `DESTDIR`;
- automated regression tests.

The development suite currently has **41 automated tests** covering policies,
wiring, runtime behavior, reports, system layout, installation, log rotation
and systemd integration.

---

## Safety model

The workflow is designed so package installation occurs only after every safety stage has completed:

```text
System checks
    ↓
Detect available updates
    ↓
Prepare Arch News context
    ↓
Inspect removals
    ↓
Inspect replacements
    ↓
Collect libalpm transaction additions
    ↓
Collect repository/package/version metadata
    ↓
Reject non-stable or non-official candidates
    ↓
Run policies
    ↓
Aggregate final decision
    ↓
Decision Gate
    ↓
ALLOW / WARNING ──→ install only in guarded mode
BLOCK           ──→ installation forbidden
    ↓
Finalize report
```

A final `BLOCK` is enforced before `pacman -Syu` can run.

In the default configuration Smart Update uses `MODE="audit"`, so **no package installation is performed**.

---

## Installation from source

Requirements include Arch Linux, Bash, pacman, `pacman-contrib`, libalpm development files, libxml2 when Arch News is enabled, systemd, a C compiler and standard build tooling.

Clone the repository:

```bash
git clone https://github.com/Alyk976/smart-update.git
cd smart-update
```

Run the complete test suite before installing:

```bash
./tests/run_tests.sh
```

Install the application:

```bash
sudo make install
sudo systemctl daemon-reload
```

The installer builds the native libalpm helper and installs Smart Update into the standard system layout.

Detailed installation and removal procedures are documented in [`docs/INSTALLATION.md`](docs/INSTALLATION.md).

---

## Installed layout

A normal system installation uses:

```text
/usr/bin/smart-update
/usr/lib/smart-update/
/usr/lib/smart-update/policies/
/usr/lib/smart-update/package-removals-helper
/etc/smart-update/smart-update.conf
/etc/smart-update/critical-packages.conf
/etc/logrotate.d/smart-update
/usr/lib/systemd/system/smart-update.service
/usr/lib/systemd/system/smart-update.timer
/usr/lib/tmpfiles.d/smart-update.conf
/usr/share/licenses/smart-update/LICENSE
/usr/share/licenses/smart-update/NOTICE
/var/lib/smart-update/
/var/log/smart-update/
/var/log/smart-update/reports/
```

Configuration under `/etc/smart-update/` is preserved when `make install` is run again.

For development, Smart Update can still run directly from the repository:

```bash
sudo ./bin/smart-update
```

---

## Operating modes

Configuration is stored in:

```text
/etc/smart-update/smart-update.conf
```

when installed system-wide, or `config/smart-update.conf` when running from the repository.

### Audit mode

```bash
MODE="audit"
```

Audit mode performs checks, transaction analysis, policy evaluation and report generation but never installs packages.

This is the default and recommended mode during validation.

### Guarded mode

```bash
MODE="guarded"
```

For an ordinary transaction, guarded mode may execute Pacman with a
conservative non-interactive question mask:

```bash
pacman -Syu --ask=75
```

but only after both the policy gate and the execution capability gate allow
the transaction. The mask does not authorize conflict removals; transactions
already known to require an interactive Pacman choice are reported as
`MANUAL_TRANSACTION_REQUIRED` before Pacman starts.

A final `BLOCK` always prevents installation.

---

## Policies

Policies are loaded dynamically from `lib/policies/` during development and `/usr/lib/smart-update/policies/` after installation.

| Policy | Purpose |
|---|---|
| `update_count` | Blocks or allows based on the configured maximum update count |
| `stable_updates` | Allows only stable candidates from `core`, `extra` and `multilib` |
| `critical_updates` | Detects updates to packages listed as critical |
| `foreign_packages` | Reports foreign/AUR packages without updating them |
| `arch_news` | Surfaces new official Arch Linux announcements |
| `package_removals` | Detects packages the transaction would remove |
| `package_replacements` | Detects package replacement operations |
| `overwrite_guard` | Prevents forced file overwrites |
| `new_dependencies` | Detects packages newly introduced by the transaction |

Each policy exposes a common contract:

```text
POLICY_NAME
POLICY_RESULT
POLICY_REASON
POLICY_DETAILS
```

Policies do not install packages. The central engine evaluates their results and the decision layer determines the final verdict.

---

## Critical packages

Critical packages are configured in:

```text
/etc/smart-update/critical-packages.conf
```

When one or more configured critical packages are included in the update set,
`ALLOW_CRITICAL_UPDATES="yes"`, the default, allows a stable critical update to
continue as `WARNING`, never silently as `ALLOW`. An administrator can select
the ultra-conservative `no` setting to block every critical update. Stability
is evaluated first, so an unstable critical update remains `BLOCK` regardless
of this setting.

Typical examples in a workstation environment include the kernel and other infrastructure-sensitive packages.

## Stable update eligibility

Before any installation, Smart Update reads repository, package name and
version directly from the prepared libalpm transaction. `core`, `extra` and
`multilib` candidates are eligible when their name and version contain no
explicit development marker. Testing, staging and unstable repositories,
third-party repositories, VCS package suffixes and explicit alpha, beta, RC,
pre, preview, dev, nightly or snapshot versions are blocked. The `-bin` suffix
and an isolated `r123` revision do not by themselves make a package unstable.

---

## Arch Linux news tracking

Smart Update can query the official Arch Linux RSS feed before an update.

Configuration:

```bash
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
```

The last processed announcement GUID is stored in:

```text
/var/lib/smart-update/arch-news.last
```

The state is updated atomically and only when the workflow permits it.

Typical behavior:

| Situation | Policy result |
|---|---|
| Arch News disabled | `ALLOW` |
| First collection | `WARNING` |
| New announcements detected | `WARNING` |
| No new announcement | `ALLOW` |
| Feed, parsing or state error | `BLOCK` |

Smart Update surfaces announcements; the administrator remains responsible for reading any required manual-intervention instructions.

---

## Transaction safety

### Package removals

Smart Update uses a native C helper linked against libalpm to inspect planned package removals.

With the default configuration:

```bash
ALLOW_REMOVALS="no"
```

any planned removal results in a blocking policy decision.

### Package replacements

Replacement operations are also detected through the libalpm helper.

Default:

```bash
ALLOW_REPLACEMENTS="no"
```

### Package additions and new dependencies

The native helper reads the prepared libalpm transaction addition list through
`alpm_trans_get_add()`. Smart Update compares those package names with the
installed package database to identify packages and dependencies that would be
introduced by the transaction. The Bash adapter for this context is
`lib/package_additions.sh`.

Default:

```bash
ALLOW_NEW_DEPENDENCIES="no"
```

When a new package or dependency appears, the transaction is blocked. If this option is explicitly set to `yes`, the policy returns `WARNING` instead.

### Forced overwrite

Smart Update does not use Pacman's `--overwrite` option in the standard workflow.

Default:

```bash
ALLOW_OVERWRITE="no"
```

The overwrite policy makes this safety expectation explicit.

---

## Configuration reference

Default configuration:

```bash
MODE="audit"
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
ALLOW_CRITICAL_UPDATES="yes"
ALLOW_REMOVALS="no"
ALLOW_NEW_DEPENDENCIES="no"
ALLOW_REPLACEMENTS="no"
ALLOW_OVERWRITE="no"
MAX_UPDATE_COUNT=500
MIN_ROOT_FREE_MIB=4096
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
AUTO_REBOOT="no"
AUTO_SNAPSHOT="no"
REPORT_RETENTION_DAYS=90
LOG_FILE="/var/log/smart-update/smart-update.log"
BLOCKED_LOG="/var/log/smart-update/blocked.log"
REPORT_DIR="/var/log/smart-update/reports"
```

Smart Update currently performs neither automatic reboot nor automatic snapshot creation.

### AUR updates through yay

Smart Update uses `LC_ALL=C yay -Qua --aur --color never` for discovery. It
classifies every `package installed_version -> candidate_version` tuple and
targets only approved stable packages with:

```bash
yay -S --aur --needed --noconfirm --color never <approved-packages...>
```

The candidate list is discovered again immediately before installation and
must match the analyzed tuples exactly. Smart Update never enables yay's devel
mode. Stable normal and `-bin` packages may be updated; VCS suffixes and alpha,
beta, RC, pre, preview, dev, nightly or snapshot versions are skipped. Unknown
Foreign packages are reported and never modified automatically.

`yay` is optional. When it is absent, official repository updates continue and
the report marks the AUR phase `NOT_AVAILABLE`. Smart Update invokes yay from
its already privileged process with `SUDO_USER`, `SUDO_UID`, `SUDO_GID` and
`HOME` derived from the validated `AUR_USER` account. yay keeps Pacman
privileged and drops its build commands to that non-root identity. `auto`
accepts only a valid non-root `SUDO_USER`; systemd automation requires an
explicit user name. Smart Update rechecks yay after the official upgrade and
never enables `--devel` or `--sudoloop`. It neither creates nor requires a new
sudoers rule.

---

## Logs and reports

### Main log

```text
/var/log/smart-update/smart-update.log
```

### Blocking-event log

```text
/var/log/smart-update/blocked.log
```

### Reports

```text
/var/log/smart-update/reports/report-YYYYMMDD-HHMMSS.txt
```

Reports include system information, installed/foreign packages, policy decisions, detected critical packages, new dependencies, final verdict, public exit code and execution duration.

The two append-only logs are covered by the optional configuration installed at
`/etc/logrotate.d/smart-update`. When `logrotate` is installed, they are rotated
weekly, eight rotations are retained, and old logs are compressed. Report files
remain governed independently by `REPORT_RETENTION_DAYS=90`.

Example final summary:

```text
Paquets à mettre à jour : 108
Paquets critiques       : 2
Nouvelles dépendances   : 1
Paquets étrangers/AUR   : 12
Verdict                  : BLOCK
Code de sortie           : 29 (POLICY_BLOCK)
Statut                    : Installation bloquée volontairement par les politiques de sécurité.
```

Report finalization is idempotent and is also attempted on controlled post-start failures.

---

## Exit codes

Smart Update exposes a stable public exit-code contract.

| Code | Label | Meaning |
|---:|---|---|
| `0` | `OK` | Normal completion |
| `1` | `GENERAL_ERROR` | Generic error |
| `10` | `LOW_DISK_SPACE` | Not enough free space |
| `11` | `PACKAGE_MANAGER_ACTIVE` | Another package manager is active |
| `12` | `STALE_PACMAN_LOCK` | Orphan Pacman lock detected |
| `20` | `INSTANCE_ALREADY_RUNNING` | Another Smart Update instance is active |
| `21` | `CHECKUPDATES_FAILED` | Update detection failed |
| `26` | `PACMAN_TRANSACTION_FAILED` | Pacman transaction failed |
| `28` | `INVALID_MODE` | Invalid operating mode |
| `29` | `POLICY_BLOCK` | Installation intentionally blocked by policies |
| `30` | `INVALID_FINAL_DECISION` | Invalid final decision state |

See [`docs/EXIT_CODES.md`](docs/EXIT_CODES.md) for operational guidance.

The systemd service declares exit code `29` as a successful controlled outcome, so a normal policy block does not make the unit appear crashed.

---

## systemd automation

Smart Update ships with:

```text
smart-update.service
smart-update.timer
```

The service executes:

```text
/usr/bin/smart-update
```

The timer uses:

```ini
OnActiveSec=5min
OnUnitActiveSec=1d
Persistent=true
```

Enable it with:

```bash
sudo systemctl enable --now smart-update.timer
```

Inspect scheduling with:

```bash
systemctl status smart-update.timer
systemctl list-timers smart-update.timer --all
```

With the default `MODE="audit"`, scheduled runs analyze the system but do not install packages.

---

## Development and validation

Run the complete suite:

```bash
./tests/run_tests.sh
```

Useful validation commands:

```bash
bash -n bin/smart-update lib/*.sh lib/policies/*.sh
shellcheck -x bin/smart-update lib/*.sh lib/policies/*.sh tests/*.sh
systemd-analyze verify systemd/smart-update.service systemd/smart-update.timer
git diff --check
```

The installation path can be tested without writing to the live system by using `DESTDIR`:

```bash
rootfs=$(mktemp -d)
make DESTDIR="$rootfs" install
```

The automated suite already validates this installation method.

---

## Project architecture

```text
smart-update/
├── bin/
│   └── smart-update
├── config/
│   ├── smart-update.conf
│   └── critical-packages.conf
├── docs/
├── lib/
│   ├── policies/
│   ├── arch_news.sh
│   ├── arch_news_context.sh
│   ├── arch_news_state.sh
│   ├── config.sh
│   ├── decision.sh
│   ├── engine.sh
│   ├── exit_codes.sh
│   ├── logger.sh
│   ├── package_additions.sh
│   ├── package_removals.sh
│   ├── package_replacements.sh
│   ├── report.sh
│   └── system_checks.sh
├── packaging/
│   ├── smart-update.logrotate
│   └── smart-update.tmpfiles
├── systemd/
│   ├── smart-update.service
│   └── smart-update.timer
├── tests/
├── tools/
│   └── package-removals-helper/
├── LICENSE
├── Makefile
├── NOTICE
└── README.md
```

The native helper is compiled with libalpm and is installed as:

```text
/usr/lib/smart-update/package-removals-helper
```

---

## Supported platform

| Platform | Status |
|---|---|
| Arch Linux | Supported and tested |
| Arch-based distributions | Not officially supported |
| Other distributions | Not supported |

Smart Update is intentionally tied to pacman/libalpm semantics and Arch Linux operational practices.

---

## Release

Smart Update v1.0.0 is packaged through the native Arch `PKGBUILD`. Release
validation covers the complete test suite, clean `makepkg` builds, package
integrity through Pacman, systemd integration and non-destructive logrotate
validation.

---

## License

Smart Update is licensed under the Apache License 2.0. See [`LICENSE`](LICENSE).
