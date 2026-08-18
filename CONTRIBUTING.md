# Contributing to Smart Update

Thank you for your interest in improving Smart Update.

Smart Update is a safety-oriented Arch Linux administration tool, so changes should preserve deterministic behavior, explicit policy decisions and administrator control.

## Before submitting a change

Run the project validation locally:

```bash
bash -n bin/smart-update lib/*.sh lib/policies/*.sh tests/*.sh
shellcheck -x bin/smart-update lib/*.sh lib/policies/*.sh tests/*.sh
./tests/run_tests.sh
make helper
```

Update documentation when behavior, configuration, public exit codes or operational expectations change.

## Development principles

- Prefer explicit behavior over hidden automation.
- Keep policy decisions deterministic and auditable.
- Fail safely when transaction state is ambiguous.
- Keep functions focused and readable.
- Add or update tests for behavioral changes.
- Do not bypass Pacman or libalpm authority.

## Detailed guide

See [`docs/development/CONTRIBUTING.md`](docs/development/CONTRIBUTING.md) for the project's development rules and coding style.

Feedback, bug reports and improvement ideas can be submitted through [GitHub Issues](https://github.com/Alyk976/smart-update/issues).
