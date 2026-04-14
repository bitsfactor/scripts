# BitsFactor Scripts

BitsFactor Scripts is a Bash-first bootstrap toolkit for bringing a new machine online in minutes.

Use it to:
- prepare a fresh **macOS / Linux** development machine
- use the same flow on **Windows via WSL2 Ubuntu**
- bring up a new **VPS** with SSH, GitHub access, and AI tooling
- start from one unified interactive entrypoint, or call each script directly when needed

## Quick Start

### Default entrypoint (latest)

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts/bfs.sh | bash
```

That command opens the unified launcher and resolves a concrete release version before it downloads any secondary scripts, so one session stays on one tagged version.

### Direct latest-first dispatch

You can also skip the menu and call a tool directly through the launcher:

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts/bfs.sh | bash -s -- codex install
```

## Windows Support

- **Official Windows support is WSL2 Ubuntu only**
- Native **PowerShell / winget / Git Bash / MSYS / Cygwin** are not supported
- On Windows, open **Ubuntu in WSL2** first, then run the same commands shown here

## Scripts

| Script | What it does | Recommended use |
| --- | --- | --- |
| `bfs.sh` | Unified launcher for all BitsFactor tools | Default entrypoint |
| `one.sh` | Full VPS bootstrap with Claude Code or Codex | Advanced / VPS-focused direct flow |
| `env.sh` | Sets system timezone and installs dev tools on macOS / Linux | Called through `bfs.sh env ...` or directly |
| `git.sh` | Reuses a GitHub SSH key on a new machine | Called through `bfs.sh git ...` or directly |
| `claude.sh` | Installs and configures Claude Code | Called through `bfs.sh claude ...` or directly |
| `codex.sh` | Installs Codex, auto-installs `rg`, adds `codex-yolo`, and configures API | Called through `bfs.sh codex ...` or directly |
| `pytools.sh` | Installs Python CLI tools into `~/pytools` | Called through `bfs.sh pytools ...` or directly |

## Launcher Examples

```bash
# open the unified interactive menu
bash bfs.sh

# direct local dispatch examples
bash bfs.sh env install-all
bash bfs.sh git set-key
bash bfs.sh claude set-api
bash bfs.sh codex install
bash bfs.sh pytools uninstall
```

## Overview

- `bfs.sh` — unified menu + direct dispatcher for all BitsFactor tools
- `one.sh` — runs `env.sh`, `git.sh`, then continues with either Claude Code or Codex setup
- `env.sh` — sets system timezone (default `Asia/Shanghai` via `BFS_TIMEZONE`), installs Homebrew (macOS), Git, Python3, Node.js, Go, Docker, and optional SSH port changes on Linux
- `git.sh` — retrieves and installs your GitHub SSH private key
- `claude.sh` — installs or updates Claude Code, sets API config, enables Trust All Tools, manages oosp, or uninstalls
- `codex.sh` — installs Codex, auto-installs `ripgrep` (`rg`) on macOS / Linux, adds `codex-yolo` for maximum autonomy, and writes third-party API config
- `pytools.sh` — installs or removes Python CLI tools under `~/pytools`

## Advanced: pinned version commands

Pinned commands are mainly for development / testing / rollback workflows.

```bash
BFS_VER=1.3.17
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/bfs.sh | BFS_VER=$BFS_VER bash
```

### Direct pinned script commands

| Script | Run |
| --- | --- |
| `one.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh \| BFS_VER=$BFS_VER bash` |
| `env.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh \| BFS_VER=$BFS_VER bash` |
| `git.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh \| BFS_VER=$BFS_VER bash` |
| `claude.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh \| BFS_VER=$BFS_VER bash` |
| `codex.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh \| BFS_VER=$BFS_VER bash` |
| `pytools.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh \| BFS_VER=$BFS_VER bash` |
| `bfs.sh` | `BFS_VER=1.3.17; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/bfs.sh \| BFS_VER=$BFS_VER bash` |
