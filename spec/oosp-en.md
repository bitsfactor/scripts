# OOSP Specification (Object-Oriented Standardized Programming)

## Core Principles
- One file per class; no inheritance, use composition
- Every class and function must have comments
- Third-party libraries must be wrapped in a class

## Namespace
`{layer}.{class}` → file path
Example: `data.database` → `src/data/database.js`

## Directory Structure
```
.env          # Environment variables (keys, passwords, server credentials). Never commit to git.
scripts/      # Shell utility scripts.
├── setup.sh         # Interactive setup script. Subcommands: install, configure, deploy, update, etc.
test/         # Test directory
├── business/        # Unit tests for the Business layer
src/          # Source code
├── web/             # UI layer - Web interface
├── cli/             # UI layer - Command line
├── api/             # UI layer - External service interface
├── business/        # Business logic layer
├── data/            # Data access layer
├── model/           # Model layer
├── common/          # Common layer
└── config/          # Configuration
```

## Layer Dependencies
```
web/cli/api → business → data
                 ↓        ↙
          model / common / config
```

## Key Rules
- No inheritance — use composition
- Model layer holds data only, no behavior functions
- Public functions of Business layer classes must have unit tests. Lower layers don't require tests. Upper layers don't mandate tests.
