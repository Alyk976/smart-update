# Smart Update v2 — Installation and operations

This document describes source installation, validation, systemd activation and manual removal for Smart Update v2 on Arch Linux.

## Prerequisites

Smart Update is designed for Arch Linux and depends on pacman/libalpm semantics.

Required tooling includes:

- Bash;
- pacman;
- `pacman-contrib` for `checkupdates`;
- libalpm headers and library;
- libxml2 when Arch News is enabled;
- systemd;
- GCC or another compatible C compiler;
- GNU make;
- standard POSIX/GNU command-line utilities.

Before installation, validate the repository:

```bash
./tests/run_tests.sh
```

## Install from the repository

From the project root:

```bash
sudo make install
sudo systemctl daemon-reload
```

The build compiles the native libalpm transaction helper and installs Smart Update into the system layout.

Configuration files are created only when absent. Running `make install` again does not overwrite an existing administrator configuration under `/etc/smart-update/`.

## Installed files

The main installed paths are:

```text
/usr/bin/smart-update
/usr/lib/smart-update/
/usr/lib/smart-update/policies/
/usr/lib/smart-update/package-removals-helper
/etc/smart-update/smart-update.conf
/etc/smart-update/critical-packages.conf
/usr/lib/systemd/system/smart-update.service
/usr/lib/systemd/system/smart-update.timer
/var/lib/smart-update/
/var/log/smart-update/
/var/log/smart-update/reports/
```

Expected high-level permissions are:

```text
/usr/bin/smart-update                         0755
/usr/lib/smart-update/*.sh                   0644
/usr/lib/smart-update/policies/*.sh          0644
/usr/lib/smart-update/package-removals-helper 0755
/etc/smart-update                            0750
/etc/smart-update/*.conf                     0640
/var/lib/smart-update                        0750
/var/log/smart-update                        0750
/var/log/smart-update/reports                0750
```

## Safe first run

The default configuration uses audit mode:

```bash
sudo grep '^MODE=' /etc/smart-update/smart-update.conf
```

Expected value:

```text
MODE="audit"
```

Run Smart Update manually:

```bash
sudo /usr/bin/smart-update
rc=$?
printf 'Smart Update exit code: %d\n' "$rc"
```

A policy-driven `BLOCK` returns exit code `29`. This is a controlled safety outcome, not a crash.

## Inspect the latest report

```bash
latest_report=$(
    sudo find /var/log/smart-update/reports \
        -type f -name 'report-*.txt' \
        -printf '%T@ %p\n' |
    sort -nr |
    head -n1 |
    cut -d' ' -f2-
)

sudo less "$latest_report"
```

## systemd service

Validate the installed unit:

```bash
systemctl cat smart-update.service
```

The service must execute:

```text
ExecStart=/usr/bin/smart-update
```

A policy block (`29`) is declared as a controlled successful status through:

```text
SuccessExitStatus=29
```

Manual service run:

```bash
sudo systemctl start smart-update.service
systemctl status smart-update.service --no-pager -l
```

## systemd timer

The timer schedule is relative to timer activation:

```ini
OnActiveSec=5min
OnUnitActiveSec=1d
Persistent=true
```

Enable it:

```bash
sudo systemctl enable --now smart-update.timer
```

Validate scheduling:

```bash
systemctl status smart-update.timer --no-pager -l
systemctl list-timers smart-update.timer --all --no-pager
```

A healthy timer should normally show:

```text
Active: active (waiting)
```

with a future trigger time.

Disable automation without uninstalling Smart Update:

```bash
sudo systemctl disable --now smart-update.timer
```

## Logs

Main log:

```text
/var/log/smart-update/smart-update.log
```

Blocking events:

```text
/var/log/smart-update/blocked.log
```

systemd journal:

```bash
sudo journalctl -u smart-update.service --no-pager
```

## Configuration changes

Edit:

```bash
sudoedit /etc/smart-update/smart-update.conf
```

The default `MODE="audit"` should be retained until the administrator is satisfied with repeated audit results.

`MODE="guarded"` allows package installation when the final decision is not `BLOCK`.

## DESTDIR validation

The install layout can be tested without writing to the live root filesystem:

```bash
rootfs=$(mktemp -d)
make DESTDIR="$rootfs" install
find "$rootfs" -maxdepth 5 -type f | sort
```

The automated test `tests/test_install_destdir.sh` validates this workflow.

## Updating an existing source installation

From an updated repository checkout:

```bash
git pull --ff-only
./tests/run_tests.sh
sudo make install
sudo systemctl daemon-reload
```

Then confirm the configuration is still present and unchanged as intended.

## Manual removal

Until the Arch package is finalized, manual removal can be performed explicitly.

First stop and disable the timer:

```bash
sudo systemctl disable --now smart-update.timer 2>/dev/null || true
sudo systemctl stop smart-update.service 2>/dev/null || true
```

Remove installed application files and units:

```bash
sudo rm -f /usr/bin/smart-update
sudo rm -rf /usr/lib/smart-update
sudo rm -f \
    /usr/lib/systemd/system/smart-update.service \
    /usr/lib/systemd/system/smart-update.timer
sudo systemctl daemon-reload
```

Configuration and runtime data are intentionally separate. Remove them only when you explicitly want to discard local configuration, state and logs:

```bash
sudo rm -rf /etc/smart-update
sudo rm -rf /var/lib/smart-update
sudo rm -rf /var/log/smart-update
```

Do not remove those directories automatically when they contain data you want to preserve.
