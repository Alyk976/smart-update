# Smart Update — Exit-code contract

Smart Update exposes explicit process exit codes so administrators, scripts and systemd can distinguish normal completion, controlled policy blocking and technical failures.

## Public codes

| Code | Label | Meaning |
|---:|---|---|
| `0` | `OK` | Normal completion |
| `1` | `GENERAL_ERROR` | Generic error |
| `10` | `LOW_DISK_SPACE` | Insufficient free space on `/` |
| `11` | `PACKAGE_MANAGER_ACTIVE` | Another package manager is active |
| `12` | `STALE_PACMAN_LOCK` | Pacman lock exists without an active package-manager process |
| `20` | `INSTANCE_ALREADY_RUNNING` | Another Smart Update instance already holds the runtime lock |
| `21` | `CHECKUPDATES_FAILED` | `checkupdates` failed unexpectedly |
| `26` | `PACMAN_TRANSACTION_FAILED` | Pacman refused or aborted the installation transaction |
| `28` | `INVALID_MODE` | Unsupported operating mode in configuration |
| `29` | `POLICY_BLOCK` | Installation intentionally blocked by the policy engine |
| `30` | `INVALID_FINAL_DECISION` | Final decision state is inconsistent or invalid |
| `31` | `AUR_DISCOVERY_FAILED` | AUR discovery or anti-TOCTOU validation failed |
| `32` | `AUR_UPDATE_FAILED` | Official phase succeeded but targeted yay update failed |
| `33` | `OFFICIAL_TRANSACTION_DRIFT` | Official transaction changed before installation |
| `34` | `MANUAL_TRANSACTION_REQUIRED` | Pacman choices require manual execution |

The canonical implementation lives in:

```text
lib/exit_codes.sh
```

## Controlled outcomes

Exit codes `29` and `34` are controlled outcomes.

Code `29` means Smart Update completed enough analysis to determine that
installation must not proceed. Examples include:

- critical updates detected;
- forbidden package removals;
- forbidden package replacements;
- forbidden new dependencies;
- blocking Arch News state or collection conditions;
- another blocking policy result.

A `29` should therefore be interpreted as:

```text
Smart Update worked as designed and refused an unsafe transaction.
```

It is not equivalent to a process crash.

Code `34` means the transaction passed the policy gate but requires a Pacman
choice that Smart Update deliberately refuses to automate. The report records
`MANUAL_TRANSACTION_REQUIRED`, and neither the official nor the AUR
installation phase starts. Direct invocations still return `34` so callers can
distinguish this result from `0` and `29`.

## systemd integration

The shipped service contains:

```ini
SuccessExitStatus=29 34
```

This tells systemd that `0`, `29` and `34` are controlled outcomes for the
service. It does not change the process exit code recorded in the report or
returned outside systemd.

As a result, a normal policy block can appear as:

```text
Deactivated successfully.
Finished Smart Update guarded Arch Linux update service.
```

while the Smart Update report still records:

```text
Verdict                  : BLOCK
Code de sortie           : 29 (POLICY_BLOCK)
```

Exit code `31` and every other non-zero code except `29` and `34` remain visible
as service failures. In particular, an unavailable AUR identity while AUR
updates are enabled returns `31` before any official installation can start.

## Reports

When a report has been created, Smart Update attempts to finalize it with the process exit code.

The final summary includes:

```text
Verdict
Code de sortie
Statut
Durée
```

This lets an administrator distinguish the policy verdict from the process-level reason for termination.

## Shell usage

Direct execution:

```bash
sudo /usr/bin/smart-update
rc=$?
printf 'exit=%d\n' "$rc"
```

Example handling:

```bash
case "$rc" in
    0)
        echo 'Smart Update completed normally.'
        ;;
    29)
        echo 'Smart Update intentionally blocked the transaction.'
        ;;
    34)
        echo 'Smart Update requires a manual Pacman transaction.'
        ;;
    *)
        echo "Smart Update failed with technical exit code $rc." >&2
        ;;
esac
```

## Stability

These codes are treated as part of the public runtime contract for the v1 release line. Changes should be deliberate, documented and covered by regression tests.
