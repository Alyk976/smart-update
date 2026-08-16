# Smart Update — Guide utilisateur

## Purpose

Smart Update analyzes an Arch Linux update transaction before deciding whether
installation is acceptable, and in guarded mode it can install an allowed
transaction. It does not replace Pacman and does not override administrator
policy.

The default configuration uses `MODE="audit"`; this mode performs analysis and
produces a report without installing packages.

## Run an audit

```bash
sudo /usr/bin/smart-update
rc=$?
printf 'Smart Update exit code: %d\n' "$rc"
```

The most important controlled results are:

- `0`: analysis completed normally;
- `29`: a policy deliberately blocked installation;
- any other non-zero code: a technical or configuration failure.

A policy block is a successful safety outcome, not a crash.

## Understand the decision

Smart Update evaluates update count, critical packages, foreign/AUR packages,
Arch News, removals, replacements, new packages and dependencies, and the
forced-overwrite guard. It also rejects candidates from testing, staging,
unstable or unknown repositories, VCS packages, and explicit pre-release
versions.

Removals, replacements and additions come from the prepared libalpm transaction.
New packages and dependencies are derived from its addition list and the local
installed package database.

The final verdict is one of:

- `ALLOW`: no policy objected;
- `WARNING`: review is recommended, but the decision gate permits continuation;
- `BLOCK`: installation is forbidden.

Even an allowed audit does not install packages. Installation is possible only
in `guarded` mode and only after the final decision gate.

## Configuration

System configuration lives in:

```text
/etc/smart-update/smart-update.conf
/etc/smart-update/critical-packages.conf
```

Edit configuration with `sudoedit` and retain restrictive permissions. Important
safe defaults include:

```bash
MODE="audit"
ALLOW_CRITICAL_UPDATES="yes"
ALLOW_REMOVALS="no"
ALLOW_NEW_DEPENDENCIES="no"
ALLOW_REPLACEMENTS="no"
ALLOW_OVERWRITE="no"
AUTO_REBOOT="no"
AUTO_SNAPSHOT="no"
REPORT_RETENTION_DAYS=90
```

`ALLOW_CRITICAL_UPDATES="yes"` is the normal default. It permits a critical
package only after it passes the stable-update policy; the critical policy then
returns `WARNING`, so the event remains visible while guarded mode may proceed.
An administrator can explicitly select `no` to force every critical update to
`BLOCK`. An unstable critical candidate always remains `BLOCK`, because the
stable-update policy cannot be bypassed by this setting.

Stable official candidates from `core`, `extra` and `multilib` are eligible.
AUR automation is disabled in the distributed configuration:

```bash
ENABLE_AUR_UPDATES="no"
AUR_HELPER="yay"
AUR_USER="auto"
```

For a manual `sudo smart-update` invocation, stable AUR updates can be enabled
while `auto` resolves the trustworthy non-root `SUDO_USER`:

```bash
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
```

For timer execution there is no trustworthy calling user, so activation
requires an explicit identity:

```bash
ENABLE_AUR_UPDATES="yes"
AUR_USER="username"
```

If AUR updates are enabled but the identity cannot be resolved, Smart Update
records the reason in the report and returns `31` before any official package
transaction can modify the system.

Never use `root` as `AUR_USER`, and do not grant `NOPASSWD: ALL`. Smart Update
does not modify sudoers. It invokes yay while retaining the root context already
required for the official update, but supplies `SUDO_USER`, `SUDO_UID`,
`SUDO_GID` and `HOME` exclusively from the validated account database entry.
The current implementation relies on yay to drop build commands to the
non-root AUR identity. The `yay -S` process itself is still launched from the
root orchestrator; the non-root build and root installation responsibilities
are not yet isolated into separate components. AUR automation by timer must
therefore not be considered fully hardened in Smart Update 1.1.0.

Immediately before any AUR installation, Smart Update checks yay again. This
is mandatory when the official candidate set contains `pacman`, and still
performed otherwise. If the newly installed pacman/libalpm makes yay
incompatible, the AUR result is `DEFERRED_HELPER_INCOMPATIBLE`, no AUR install
is attempted, and the run returns a partial non-zero result without rolling
back the successful official update.

Smart Update approves stable normal and `-bin` candidates. VCS packages and
explicit alpha, beta, RC, pre, preview, dev, nightly or snapshot versions are
skipped without preventing other stable AUR or official updates. Foreign
packages absent from the AUR are reported but never changed.

## Logs and reports

```text
/var/log/smart-update/smart-update.log
/var/log/smart-update/blocked.log
/var/log/smart-update/reports/
```

Reports contain the transaction summary, policy reasons, final verdict, public
exit code and execution duration. Smart Update deletes only report files older
than `REPORT_RETENTION_DAYS`, which defaults to 90 days.

If the optional `logrotate` package is installed,
`/etc/logrotate.d/smart-update` rotates the two logs weekly, keeps eight
rotations and compresses old logs. It does not manage reports.

## systemd automation

Enable the daily timer only after reviewing manual audit results:

```bash
sudo systemctl enable --now smart-update.timer
systemctl status smart-update.timer --no-pager -l
```

Disable automation without removing Smart Update:

```bash
sudo systemctl disable --now smart-update.timer
```

Exit codes `29` and `34` are listed in `SuccessExitStatus` and therefore appear
as controlled service results. Exit code `31` and every other non-zero code
remain failures. Consult both the service journal and the latest report when
investigating an execution:

```bash
sudo journalctl -u smart-update.service --no-pager
```

## Operational safety

- Read Arch News before approving updates that require manual intervention.
- Review every package removal, replacement and addition.
- Keep `audit` mode until repeated results are understood.
- Never delete `/var/lib/pacman/db.lck` without checking for an active package
  manager process.
- Do not treat `WARNING` as equivalent to risk-free operation.
