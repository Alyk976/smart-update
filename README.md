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


## Project Structure

```text
smart-update-v2/
├── bin/            # Application entry point
├── config/         # Configuration files and policies
├── docs/           # Project documentation
├── lib/            # Core modules
├── scripts/        # Development and maintenance scripts
├── systemd/        # Service and timer units
├── tests/          # Automated test suite
├── PROGRESS.md     # Development progress tracking
└── README.md       # Project documentation
```

### Directory Overview

| Directory | Purpose |
|-----------|---------|
| `bin/` | Contains the main executable that orchestrates the update workflow. |
| `config/` | Stores configuration files and policy definitions used by the decision engine. |
| `docs/` | Contains architecture, development, user and vision documentation. |
| `lib/` | Implements the project's core logic, including policies, decisions, logging, reporting and system checks. |
| `scripts/` | Reserved for development and maintenance utilities. |
| `systemd/` | Provides service and timer units for scheduled execution. |
| `tests/` | Contains the automated regression and unit test suite. |
| `PROGRESS.md` | Tracks completed work, milestones and upcoming tasks. |

This directory layout keeps the project modular and scalable while clearly separating execution, configuration, documentation, testing and core business logic.

---


## Requirements

Smart Update is currently developed and tested exclusively on **Arch Linux**.

### Software Requirements

| Component | Requirement |
|-----------|-------------|
| Operating System | Arch Linux |
| Bash | Version 5.2 or later |
| pacman | Native Arch Linux package manager |
| systemd | Required for scheduled execution |
| Git | Required to clone the repository |

### Permissions

Smart Update performs system maintenance and package management operations. As a result, it must be executed with **root privileges** or through `sudo`.

### Tested Environment

| Component | Status |
|-----------|--------|
| Arch Linux | ✅ Supported |
| Arch-based distributions (Manjaro, EndeavourOS, CachyOS, etc.) | ⚠️ Not officially tested |
| Other Linux distributions | ❌ Not supported |

> **Note**
>
> Smart Update relies on Arch Linux's native package management tools and system architecture. Compatibility with Arch-based distributions may be evaluated in future releases.

---


## Future Vision

Smart Update is designed to remain a deterministic, policy-driven update decision engine.

In the long term, the project aims to introduce an **optional AI advisor** capable of assisting system administrators while preserving the deterministic behavior of the policy engine.

The guiding principle of this evolution is:

> **The AI advises. Policies decide. The administrator remains in control.**

Potential future capabilities include:

- AI-assisted update risk analysis
- Human-readable explanations for policy decisions
- Intelligent update summaries
- Configuration assistance
- Log and report analysis
- Interactive troubleshooting
- Historical execution analysis and recommendations

The AI advisor will never replace the policy engine or make update decisions autonomously. It will consume the structured output of Smart Update and provide explanations and recommendations only.

AI integration will remain **optional**, allowing Smart Update to operate entirely offline and without external services when desired.

---

## Project Status

Current version: **v0.2-dev**

This project is under active development.

---

## License

To be defined.
