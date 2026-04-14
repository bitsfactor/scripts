# BitsFactor Scripts

BitsFactor Scripts is a Bash-first machine bootstrap toolkit for setting up a fresh development machine or VPS with a small set of focused, versioned scripts.

It is designed for people who want:
- a **single interactive entrypoint** for the common setup flow
- the option to run **individual setup scripts directly**
- a **latest-first** default install path for convenience
- a **pinned-version** path for development, testing, and rollback
- a pragmatic, low-dependency toolchain that works on **macOS**, **Linux**, and **Windows via WSL2 Ubuntu**

## Table of Contents

- [Project Status](#project-status)
- [Highlights](#highlights)
- [Supported Platforms](#supported-platforms)
- [Quick Start](#quick-start)
- [Installation Modes](#installation-modes)
- [Command Reference](#command-reference)
- [Repository Layout](#repository-layout)
- [Project Docs](#project-docs)
- [Development](#development)
- [Testing](#testing)
- [Release Process](#release-process)
- [Security Notes](#security-notes)
- [Contributing](#contributing)
- [License](#license)

## Project Status

- **Status:** active
- **Primary entrypoint:** `bfs.sh`
- **Current version source of truth:** `version.sh`
- **Windows support policy:** **WSL2 Ubuntu only**

This repository intentionally stays Bash-first. It does not currently provide a native PowerShell or winget implementation.

## Highlights

- **Unified launcher** — `bfs.sh` provides a single menu-driven entrypoint and direct command dispatch.
- **Latest-first UX** — the default public command is short and does not require manually typing a version.
- **Release consistency** — the launcher resolves one concrete tagged release before downloading follow-on scripts, so a single session stays on one release.
- **Direct-script compatibility** — existing script entrypoints remain available for advanced usage.
- **Low operational overhead** — no framework, no build system, no extra runtime dependency beyond standard shell tools.
- **Test coverage for the command surface** — the repository now includes a lightweight Bash test harness for the exposed subcommands and launcher dispatch paths.

## Supported Platforms

| Platform | Status | Notes |
| --- | --- | --- |
| macOS | Supported | Native support |
| Linux (Debian/Ubuntu-oriented) | Supported | Native support |
| Windows + WSL2 Ubuntu | Supported | Official Windows path |
| Native PowerShell | Not supported | Out of scope in current architecture |
| Git Bash / MSYS / Cygwin | Not supported | Use WSL2 Ubuntu instead |

### Windows usage policy

If you are on Windows:
1. install **WSL2**
2. install **Ubuntu** inside WSL2
3. open the Ubuntu shell
4. run the same commands documented below

The scripts will explicitly fail fast in unsupported native Windows shells so that the support boundary is clear.

## Quick Start

### Recommended: latest interactive launcher

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts/bfs.sh | bash
```

This command:
- starts the unified BitsFactor launcher
- resolves the latest published release
- locks the session to that concrete release before downloading secondary scripts

### Recommended: latest direct dispatch

If you already know what you want to run, you can dispatch directly through the launcher:

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts/bfs.sh | bash -s -- codex install
```

### Pinned version launcher

Pinned commands are mainly intended for development, testing, and rollback workflows.

```bash
BFS_VER=1.3.17
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/bfs.sh | BFS_VER=$BFS_VER bash
```

## Installation Modes

### 1. Interactive launcher mode

Use the launcher if you want one consistent starting point:

```bash
bash bfs.sh
```

The launcher exposes these top-level areas:
- environment setup
- Git / SSH setup
- Claude Code setup
- Codex setup
- PyTools management
- VPS bootstrap

### 2. Launcher direct-dispatch mode

Use the launcher as a stable CLI dispatcher when you do not need the menu:

```bash
bash bfs.sh env install-all
bash bfs.sh git set-key
bash bfs.sh claude set-api
bash bfs.sh codex install
bash bfs.sh pytools uninstall
```

### 3. Direct-script mode

All legacy script entrypoints remain available. This is useful when:
- you are debugging a specific script
- you want a narrow command in automation
- you prefer the original per-script flow

## Command Reference

### Unified launcher

| Script | Purpose | Example |
| --- | --- | --- |
| `bfs.sh` | Unified menu + direct dispatcher | `bash bfs.sh codex install` |

### Direct scripts

| Script | Purpose | Typical use |
| --- | --- | --- |
| `one.sh` | Guided VPS bootstrap | `bash one.sh` |
| `env.sh` | System timezone + dev tooling setup | `bash env.sh install-all` |
| `git.sh` | SSH key retrieval / installation for GitHub | `bash git.sh set-key` |
| `claude.sh` | Claude Code install, API config, trust-all, oosp, uninstall | `bash claude.sh install` |
| `codex.sh` | Codex install and API config | `bash codex.sh set-api` |
| `pytools.sh` | Install or remove Python CLI helpers under `~/pytools` | `bash pytools.sh install` |

### Latest-first remote commands

| Target | Command |
| --- | --- |
| Unified launcher | `curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts/bfs.sh \| bash` |
| Launcher direct dispatch | `curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts/bfs.sh \| bash -s -- env install-all` |

### Pinned remote commands

| Target | Command |
| --- | --- |
| `bfs.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/bfs.sh \| BFS_VER=$BFS_VER bash` |
| `one.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh \| BFS_VER=$BFS_VER bash` |
| `env.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh \| BFS_VER=$BFS_VER bash` |
| `git.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh \| BFS_VER=$BFS_VER bash` |
| `claude.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh \| BFS_VER=$BFS_VER bash` |
| `codex.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh \| BFS_VER=$BFS_VER bash` |
| `pytools.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh \| BFS_VER=$BFS_VER bash` |

## Repository Layout

```text
.
├── bfs.sh          # unified launcher
├── one.sh          # VPS-oriented guided bootstrap
├── env.sh          # base environment setup
├── git.sh          # Git / SSH key workflow
├── claude.sh       # Claude Code setup and config
├── codex.sh        # Codex setup and config
├── pytools.sh      # Python helper installer
├── pytools/        # standalone Python utilities
├── spec/           # project notes and spec material
├── promp/          # prompt/reference material
├── tests/          # Bash test harness
└── version.sh      # release version source of truth
```

## Project Docs

- [`README.md`](./README.md) — project overview and usage guide
- [`CONTRIBUTING.md`](./CONTRIBUTING.md) — contributor workflow and coding/testing expectations
- [`CHANGELOG.md`](./CHANGELOG.md) — structured project changelog from the current polish pass forward
- [`SECURITY.md`](./SECURITY.md) — security reporting and sensitive-surface guidance
- [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md) — behavior expectations for project collaboration
- [`.github/ISSUE_TEMPLATE/`](./.github/ISSUE_TEMPLATE/) — issue intake templates for bugs and feature requests
- [`.github/pull_request_template.md`](./.github/pull_request_template.md) — default pull request checklist and validation prompt

## Development

There is no build system. Development is done by editing the scripts directly.

### Local development workflow

```bash
# inspect current shell scripts
bash -n *.sh

# run the main test harness
bash tests/run.sh

# run a specific script locally
bash bfs.sh
bash env.sh install-all
bash codex.sh install
```

### Versioning model

- `version.sh` is the single source of truth for the current release version
- tagged versions are used for immutable published script URLs
- the launcher resolves a concrete release version before secondary downloads when running in latest mode

## Testing

The repository now includes a dependency-light Bash test harness under `tests/`.

### What is covered

- launcher menu rendering
- launcher direct-dispatch paths
- latest version resolution behavior
- pinned-version behavior
- native Windows fast-fail messaging
- direct subcommand coverage for the major scripts
- `pytools.sh` direct subcommand parity

### Verification commands

```bash
bash -n bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh \
  tests/run.sh tests/lib/assert.sh tests/lib/test-helpers.sh

bash tests/run.sh

git diff --check
```

### Current verification limitation

The repository-level automated tests do **not** replace a real end-to-end smoke test inside an actual WSL2 Ubuntu environment. WSL2 is the official Windows support path, so real-environment validation is still recommended when that environment is available.

## Release Process

For a release:
1. update `version.sh`
2. update any pinned version examples in `README.md`
3. commit the changes
4. create and push the matching tag

Example flow:

```bash
VER="$(cut -d= -f2 version.sh | tr -d '"')"

git add -A
git commit -m "chore: bump version to $VER"
git tag "v$VER"
git push origin main
git push origin "v$VER"
```

Published jsDelivr tag URLs are immutable, so make sure the version and tag are correct before pushing.

## Security Notes

- do not commit API keys, SSH private keys, or machine-specific secrets
- verify changes to remote installer URLs carefully
- verify shell RC mutations carefully
- prefer `ed25519` SSH keys when creating new keys
- treat remote `curl | bash` usage as a release-sensitive surface; keep versioning and release tagging disciplined

## Contributing

Contributions should stay aligned with the repository’s current design goals:
- Bash-first implementation
- low dependency surface
- macOS/Linux native support
- Windows support through WSL2 Ubuntu only
- additive compatibility over breaking changes

Before submitting changes, at minimum:

```bash
bash -n bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh \
  tests/run.sh tests/lib/assert.sh tests/lib/test-helpers.sh

bash tests/run.sh
```

If you change versioned install examples, update both:
- `version.sh`
- matching pinned examples in `README.md`

## License

This project is licensed under the [MIT License](./LICENSE).
