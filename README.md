# Smart Update v2

> **Think first. Update safely.**

Smart Update v2 is a policy-driven update decision engine for Arch Linux.

It does not blindly run `pacman -Syu`. It first inspects the system, simulates the update transaction, evaluates deterministic policies and produces a final decision:

- `ALLOW`: the workflow may continue;
- `WARNING`: the workflow may continue, but the administrator should review the reported risk;
- `BLOCK`: package installation is forbidden.

The project follows one core principle:

> **The AI advises. Policies decide. The administrator remains in control.**

---

## What Smart Update does

A normal Arch Linux update usually starts directly with:

```bash
sudo pacman -Syu
```

Smart Update adds a decision layer before installation:

```text
Detect updates
→ collect system information
→ prepare policy context
→ execute policies
→ simulate the Pacman transaction
→ enforce the final decision
→ install only when allowed
→ finalize the report
```

A `BLOCK` decision is always enforced before installation. The program cannot continue to `pacman -Syu` when the final decision is blocking.

---

## Current features

- Modular Bash architecture
- Dynamic policy loading
- Deterministic decisions: `ALLOW`, `WARNING`, `BLOCK`
- Final blocking-decision enforcement before installation
- Update-count policy
- Critical-package detection
- Foreign/AUR package reporting
- Detection of newly introduced packages or dependencies
- Persistent Arch Linux news tracking
- Audit mode without package installation
- Guarded mode for policy-controlled installation
- Structured logs
- Detailed execution reports
- Atomic state-file writes
- Automated regression and unit tests
- ShellCheck and shfmt compliance

---

## Quick start

Clone the repository:

```bash
git clone git@github.com:Alyk976/smart-update-v2.git
cd smart-update-v2
```

Run Smart Update:

```bash
sudo ./bin/smart-update
```

The default configuration uses audit mode, so the program analyzes the update without installing packages.

Run the automated tests:

```bash
./tests/run_tests.sh
```

---

## Operating modes

Smart Update is configured in:

```text
config/smart-update.conf
```

### Audit mode

```bash
MODE="audit"
```

Audit mode performs the checks, executes the policies, simulates the transaction and generates the logs and report.

It does **not** install packages.

### Guarded mode

```bash
MODE="guarded"
```

Guarded mode may install updates, but only when the final decision is not `BLOCK`.

Before enabling guarded mode, review the configuration, logs and reports produced in audit mode.

---

## Decision levels

| Decision | Meaning | Installation |
|----------|---------|--------------|
| `ALLOW` | No blocking risk was detected | Allowed in guarded mode |
| `WARNING` | A risk or manual review item was detected | Allowed in guarded mode |
| `BLOCK` | At least one policy refuses the transaction | Forbidden |

A warning is informative but does not automatically block the transaction.

A block is imperative and is enforced immediately before installation.

---

## Arch Linux news tracking

Arch Linux sometimes publishes announcements that require manual intervention before an update. Smart Update reads the official Arch Linux RSS feed and exposes new announcements to the policy engine.

Enable the feature with:

```bash
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
```

`ARCH_NEWS_LIMIT` is the maximum number of recent announcements collected from the feed.

### Simple behavior

#### First execution

When no previous state exists:

```text
Feed collected
→ all collected announcements are considered new
→ Arch News policy returns WARNING
→ newest GUID is saved when no blocking decision exists
```

#### Following executions

Smart Update compares the collected announcements with the last saved GUID:

```text
No announcement before the saved GUID
→ no new announcement
→ Arch News policy returns ALLOW
→ state file is not rewritten
```

When newer announcements exist:

```text
New announcements found
→ Arch News policy returns WARNING
→ announcement details are written to the log
→ newest GUID is saved when the workflow is not blocked
```

### Persistent state

The last processed announcement is stored in:

```text
/var/lib/smart-update/arch-news.last
```

The file contains one GUID and is written atomically with permissions `0640`.

Smart Update does not rewrite this file when no new announcement exists.

### Error behavior

The Arch News policy returns `BLOCK` when:

- the RSS feed cannot be downloaded;
- the feed cannot be parsed;
- the state file is invalid or unreadable;
- the saved GUID is absent from the collected feed;
- the new state cannot be saved safely.

When a blocking error occurs, the stored GUID is not advanced.

### Policy results

| Situation | Result | State behavior |
|-----------|--------|----------------|
| Arch News disabled | `ALLOW` | No collection or state update |
| First execution | `WARNING` | Newest GUID saved if workflow is not blocked |
| New announcements | `WARNING` | Newest GUID saved if workflow is not blocked |
| No new announcement | `ALLOW` | State file remains unchanged |
| Collection, parsing or state error | `BLOCK` | State is not advanced |

### Important distinction

Arch News does not decide whether a specific installed package is affected by an announcement. It guarantees that new official announcements are surfaced to the administrator before installation is allowed.

The administrator remains responsible for reading relevant announcements and applying any required manual intervention.

---

## Policies currently available

Policies are loaded dynamically from:

```text
lib/policies/
```

Current policies include:

| Policy | Purpose |
|--------|---------|
| Update count | Checks that the number of updates stays within the configured limit |
| Critical updates | Detects updates affecting critical packages |
| Foreign packages | Reports installed foreign/AUR packages |
| Arch News | Reports new official Arch Linux announcements |

Every policy returns the same contract:

```text
POLICY_NAME
POLICY_RESULT
POLICY_REASON
POLICY_DETAILS
```

Policies do not install packages, write reports or terminate the program. The engine processes their results centrally.

---

## New dependencies

Smart Update simulates the Pacman transaction and compares planned packages with currently installed packages.

When new packages or dependencies are detected:

- `ALLOW_NEW_DEPENDENCIES="yes"` produces a `WARNING`;
- `ALLOW_NEW_DEPENDENCIES="no"` produces a `BLOCK`.

A blocking result prevents installation in guarded mode.

---

## Configuration reference

### Active settings

| Setting | Default | Purpose |
|---------|---------|---------|
| `MODE` | `audit` | Selects audit or guarded mode |
| `ALLOW_AUR` | `no` | Keeps Smart Update focused on official repository updates |
| `ALLOW_NEW_DEPENDENCIES` | `no` | Controls newly introduced packages or dependencies |
| `MAX_UPDATE_COUNT` | `500` | Limits the number of updates in one run |
| `MIN_ROOT_FREE_MIB` | `4096` | Requires minimum free space on `/` |
| `CHECK_ARCH_NEWS` | `yes` | Enables official Arch Linux news tracking |
| `ARCH_NEWS_LIMIT` | `10` | Limits collected news announcements |
| `REPORT_RETENTION_DAYS` | `90` | Controls report retention |
| `LOG_FILE` | `/var/log/smart-update/smart-update.log` | Main log file |
| `BLOCKED_LOG` | `/var/log/smart-update/blocked.log` | Blocking-event log |
| `REPORT_DIR` | `/var/log/smart-update/reports` | Report directory |

### Reserved safety settings

The configuration also contains the following safety settings:

```bash
ALLOW_REMOVALS="no"
ALLOW_REPLACEMENTS="no"
ALLOW_OVERWRITE="no"
AUTO_REBOOT="no"
AUTO_SNAPSHOT="no"
```

These values express the intended safety contract. Removal, replacement and overwrite transaction policies are still planned and must not yet be considered fully enforced by the current version.

Smart Update never performs an automatic reboot or snapshot in the current version.

---

## Logs, reports and state

### Main log

```text
/var/log/smart-update/smart-update.log
```

### Blocking log

```text
/var/log/smart-update/blocked.log
```

### Reports

```text
/var/log/smart-update/reports/
```

Each report includes:

- detected updates;
- policy decisions;
- decision reasons;
- critical updates;
- new dependencies;
- foreign/AUR packages;
- final verdict;
- execution duration.

### State directory

```text
/var/lib/smart-update/
```

Current state files include:

```text
last-success
arch-news.last
```

---

## Project architecture

```text
smart-update-v2/
├── bin/                    # Main application workflow
├── config/                 # Default configuration
├── docs/                   # Architecture and project documentation
├── lib/                    # Core modules
│   ├── policies/           # Deterministic policies
│   ├── arch_news.sh        # RSS collector
│   ├── arch_news_state.sh  # Persistent news state
│   ├── arch_news_context.sh# News preparation context
│   ├── config.sh           # Configuration validation
│   ├── decision.sh         # Final decision aggregation
│   ├── engine.sh           # Policy execution engine
│   ├── logger.sh           # Structured logging
│   ├── report.sh           # Report generation
│   └── system_checks.sh    # System prerequisites
├── scripts/                # Development utilities
├── systemd/                # Service and timer units
├── tests/                  # Automated tests
├── PROGRESS.md             # Project progress
└── README.md               # Main documentation
```

The main workflow stays in `bin/smart-update`. Reusable technical logic belongs in `lib/`, while policies remain isolated in `lib/policies/`.

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| Operating system | Arch Linux |
| Bash | 5.2 or later |
| pacman | Native Arch Linux package manager |
| pacman-contrib | Provides `checkupdates` |
| libxml2 | Provides `xmllint` when Arch News is enabled |
| systemd | Required for scheduled execution |
| Git | Required to clone the repository |

Smart Update must be executed with root privileges:

```bash
sudo ./bin/smart-update
```

### Supported systems

| System | Status |
|--------|--------|
| Arch Linux | Supported |
| Arch-based distributions | Not officially tested |
| Other Linux distributions | Not supported |

---

## Development workflow

The project follows a strict development discipline:

1. define one logical objective;
2. define the architecture and contract;
3. implement the code;
4. run formatting, syntax checks, ShellCheck and tests;
5. create one focused commit;
6. document the next step.

Validation commands commonly used during development:

```bash
shfmt -w -i 4 -ci -bn <files>
bash -n <files>
shellcheck -x <files>
./tests/run_tests.sh
git diff --check
```

---

## Current status

Current development version: **v0.2-dev**

The following parts are operational and functionally tested:

- modular policy engine;
- deterministic decision aggregation;
- final `BLOCK` enforcement;
- Arch News collection, state tracking and policy workflow;
- first-run and subsequent-run Arch News behavior;
- audit-mode execution without installation;
- report and log generation.

The next planned transaction-safety work concerns package removals, replacements and forbidden overwrite behavior.

---

## Future vision

Smart Update is designed to remain deterministic and policy-driven.

A future optional AI advisor may provide explanations, summaries and troubleshooting assistance, but it will never replace the policy engine or autonomously approve an update.

> **The AI advises. Policies decide. The administrator remains in control.**

---

## License

To be defined.
