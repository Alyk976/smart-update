# Smart Update v2

> **Think first. Update safely.**

Smart Update v2 is a policy-driven update decision engine for Arch Linux.

Rather than blindly installing every available package, Smart Update analyzes the system, evaluates potential risks, applies administrator-defined policies, and determines whether an update should be allowed, warned about, or blocked.

The project is designed to provide a safer, more transparent and fully explainable update workflow while remaining fully compatible with the Arch Linux ecosystem and Pacman.

---

## Why Smart Update?

Keeping an Arch Linux system up to date is essential, but blindly installing every available package is not always the safest approach.

Smart Update introduces a policy-driven decision layer between the administrator and Pacman. Before any installation begins, the system is analyzed against configurable rules to identify situations that may require additional attention, such as critical package upgrades or new dependencies.

Instead of simply executing an update, Smart Update explains every decision it makes, allowing administrators to understand exactly why an update is allowed, warned about or blocked.

---

## Features

- Policy-driven update decision engine
- Configurable decision levels (`ALLOW`, `WARNING`, `BLOCK`)
- Administrator-defined update policies
- Critical package detection
- Detection of new packages and dependencies
- Audit mode for analysis without installation
- Detailed execution reports with decision summaries
- Structured logging
- Modular Bash architecture
- Automated test suite
- ShellCheck and shfmt compliant

---

## Project Architecture

Smart Update is designed around a modular architecture where each component has a single responsibility.

Instead of concentrating all functionality into a single script, the project separates the execution workflow, business logic, configuration, testing and system integration into dedicated modules. This organization improves maintainability, simplifies testing and makes the project easier to extend.

### Core Components

| Directory | Responsibility |
|-----------|----------------|
| `bin/` | Application entry point and update workflow |
| `lib/` | Decision engine, policies, logging and reporting modules |
| `config/` | Default configuration files |
| `tests/` | Automated regression and unit tests |
| `systemd/` | Service and timer units for scheduled execution |

This architecture allows new policies and features to be added with minimal impact on the existing codebase while keeping the update workflow predictable and easy to understand.

---

## Project Status

Current version: **v0.2-dev**

This project is under active development.

---

## License

To be defined.
