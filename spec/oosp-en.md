# OOSP Specification (Object-Oriented Standardized Programming)

## Core Principles
- One file per class; no inheritance, use composition
- Naming: all lowercase with underscores (e.g. `user_service`)
- Every class and function must have comments
- Third-party libraries must be wrapped in a class

## Namespace
`{project}.{layer}.{class}` → file path
Example: `demo.data.database` → `demo/data/database.js`

## Directory Structure
```
{project}/
├── app/web/cli/    # UI layer
├── api/            # API layer (http/ws/rpc)
├── business/       # Business logic layer
├── data/           # Data access layer
├── model/          # Model layer
├── common/         # Common layer
└── config/         # Configuration
```

## Layer Dependencies
```
UI → API → Business → Data
      ↘      ↓      ↙
      Model / Common
```

## Layer Responsibilities
- **API layer**: Organized by protocol; shared logic across protocols goes to Business layer
- **Data layer**: Data fetching and cleaning only; business logic belongs in Business layer

## Key Rules
- No inheritance — use composition
- Model layer holds data only, no behavior functions
