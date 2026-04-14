# Contributing to BitsFactor Scripts

Thanks for contributing.

This repository is intentionally small and Bash-first. The main product is the set of top-level scripts themselves, so contributions should optimize for:
- clarity
- portability
- low dependency overhead
- safe shell behavior
- backward compatibility for published install flows

## Contribution Principles

- Prefer **small, reviewable diffs**.
- Prefer **deletion over addition** when behavior can stay the same.
- Reuse existing script patterns before introducing a new abstraction.
- Do **not** add new dependencies unless they are clearly necessary and explicitly justified.
- Keep compatibility with **macOS**, **Linux**, and **Windows via WSL2 Ubuntu**.
- Do not implement native PowerShell / winget / Git Bash support unless the project scope changes.

## Project Structure

Top-level scripts are the main surface:

- `bfs.sh` — unified launcher and dispatcher
- `one.sh` — VPS-oriented guided bootstrap
- `env.sh` — base environment setup
- `git.sh` — Git / SSH key workflow
- `claude.sh` — Claude Code install / config workflow
- `codex.sh` — Codex install / config workflow
- `pytools.sh` — Python helper installer / remover
- `version.sh` — release version source of truth

Supporting content:
- `pytools/` — Python utilities installed by `pytools.sh`
- `spec/` — notes and specifications
- `promp/` — prompt/reference material
- `tests/` — Bash test harness

## Development Workflow

1. create a branch
2. make the smallest reasonable change
3. run verification locally
4. update docs when behavior changes
5. commit with a structured message

### Recommended local commands

```bash
# syntax-check edited shell files
bash -n bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh \
  tests/run.sh tests/lib/assert.sh tests/lib/test-helpers.sh

# run the repository test harness
bash tests/run.sh

# inspect local diffs for whitespace / patch issues
git diff --check
```

## Coding Guidelines

### Bash

- use `set -e`
- use 4-space indentation
- prefer clear function names such as `do_install_codex` or `tty_read`
- prefer uppercase names for exported/shared vars and lowercase snake_case for local vars/functions
- keep comments focused on non-obvious behavior
- keep remote-install compatibility in mind (`curl | bash`)

### Portability

Changes must preserve the current support policy:
- macOS: supported
- Linux: supported
- Windows: supported through **WSL2 Ubuntu only**

If a change touches shell RC handling, installer URLs, PATH mutations, or package manager calls, review it carefully for both macOS and Linux branches.

### User Experience

For user-facing output:
- keep wording direct and consistent
- use the existing ANSI color style
- avoid duplicating business logic between scripts and the launcher
- prefer the unified launcher for the default path, but keep direct script entrypoints usable

## Testing Expectations

Minimum expectation for a normal change:
- syntax-check every edited shell/test file
- run `bash tests/run.sh`
- verify docs if user-visible behavior changed

Additional expectations for higher-risk changes:
- manually exercise the affected script path
- validate latest-version resolution behavior if remote distribution changed
- validate pinned-version behavior if version handling changed
- validate WSL2 behavior if the Windows support path changed

### Current test limitation

The automated test harness is strong for repository-level behavior, but it does **not** replace a real WSL2 Ubuntu smoke test.

## Documentation Expectations

If you change any of the following, update `README.md` and related docs in the same PR:
- entrypoints
- supported platforms
- install commands
- versioning behavior
- release procedure
- security-sensitive behavior

## Commit Message Format

This repository uses the **Lore** commit protocol.

Every commit message should look like this:

```text
<intent line: why the change was made>

<body: narrative context>

Constraint: <external constraint>
Rejected: <alternative> | <reason>
Confidence: <low|medium|high>
Scope-risk: <narrow|moderate|broad>
Directive: <forward-looking note>
Tested: <what was verified>
Not-tested: <known gaps>
```

## Release Notes for Contributors

If your change affects published install commands or release examples:
- update `version.sh` when appropriate
- keep README examples in sync
- remember that published jsDelivr tag URLs are immutable

## What Not to Contribute Without Discussion

Open a design discussion first if the change would:
- rewrite the project in another language
- add a new dependency or framework
- add native Windows support outside WSL2 Ubuntu
- remove existing direct script entrypoints
- change the release/versioning model
- change the remote installer domain or trust model

## Security

Do not commit:
- API keys
- private SSH keys
- personal machine config
- shell history or real secret material

If you believe you found a security issue, read `SECURITY.md` before filing a public report.
