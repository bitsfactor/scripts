# BitsFactor Scripts

BitsFactor Scripts is a versioned set of Bash bootstrap tools for bringing a new machine online in minutes.

Use it to:
- prepare a fresh **Mac / Linux** development machine
- bring up a new **VPS** with SSH, GitHub access, and AI tooling
- run each setup step independently with simple `curl | bash` commands

## Scripts

| Script | What it does | Run |
| --- | --- | --- |
| `one.sh` | Full VPS bootstrap with Claude Code or Codex | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh &#124; BFS_VER=$BFS_VER bash |
| `env.sh` | Installs dev tools on macOS / Linux | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh &#124; BFS_VER=$BFS_VER bash |
| `git.sh` | Reuses a GitHub SSH key on a new machine | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh &#124; BFS_VER=$BFS_VER bash |
| `claude.sh` | Installs and configures Claude Code | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh &#124; BFS_VER=$BFS_VER bash |
| `codex.sh` | Installs and configures Codex | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh &#124; BFS_VER=$BFS_VER bash |
| `pytools.sh` | Installs Python CLI tools into `~/pytools` | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh &#124; BFS_VER=$BFS_VER bash |

## Overview

- `one.sh` — runs `env.sh`, `git.sh`, then continues with either Claude Code or Codex setup
- `env.sh` — installs Homebrew (macOS), Git, Python3, Node.js, Go, Docker, and optional SSH port changes on Linux
- `git.sh` — retrieves and installs your GitHub SSH private key
- `claude.sh` — installs or updates Claude Code, sets API config, enables Trust All Tools, manages oosp, or uninstalls
- `codex.sh` — installs Codex and writes third-party API config
- `pytools.sh` — installs or removes Python CLI tools under `~/pytools`
