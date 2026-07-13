# Project Principles

## Core Principles

1. Security before automation.
2. Think before updating.
3. Every decision must be explainable.
4. Administrator policies always take precedence.
5. One module, one responsibility.
6. Keep the architecture simple and modular.
7. No hidden actions.
8. No automatic override of security rules.
9. Quality is mandatory.
10. Documentation evolves with the code.

## Development Rules

- Every module must pass `bash -n`.
- Every module must pass `shellcheck`.
- Every module must have tests.
- One feature = one commit.
- Update `PROGRESS.md` after every completed sprint.

## Philosophy

Smart Update does not blindly execute updates.

It analyzes, evaluates, decides, and only then executes actions according to administrator-defined policies.
