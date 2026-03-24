# BitsFactor Scripts

Bootstrap scripts for Macs, Linux machines, and new VPS instances.

- Supports **macOS** and **Linux**
- Every script works with `curl | bash`
- All scripts share one version from `version.sh`

## Quick Start

```bash
BFS_VER=1.3.11
```

### one.sh — One-Click VPS Setup

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh | BFS_VER=$BFS_VER bash
```

Runs `env.sh`, `git.sh`, and `claude.sh` in order, with confirmation before each step.

**Steps**
- **1** `env.sh install-all`
- **2** `git.sh set-key`
- **3** `claude.sh install`
- **4** `claude.sh set-api`
- **5** `claude.sh trust-all` — Linux only

### env.sh — Development Environment Setup

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh | BFS_VER=$BFS_VER bash
```

Sets up a fresh macOS or Linux machine.

**Menu**
- **1** Install all
- **2** Install Homebrew — macOS only
- **3** Install Git
- **4** Install Python3
- **5** Install Node.js & npm
- **6** Install Go
- **7** Install Docker
- **8** Change SSH Port — Linux only

### git.sh — SSH Key Manager

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh | BFS_VER=$BFS_VER bash
```

Sets up GitHub SSH access across your machines.

**Menu**
- **1** Retrieve Keys
- **2** Set Key

### claude.sh — Claude Code Setup

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh | BFS_VER=$BFS_VER bash
```

Installs and configures Claude Code.

**Menu**
- **1** Install / Update
- **2** Set API
- **3** Trust All Tools
- **4** Install / Update oosp
- **5** Uninstall

### codex.sh — Codex Setup

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh | BFS_VER=$BFS_VER bash
```

Installs Codex or configures a third-party API.

**Menu**
- **1** Install Codex
- **2** Configure API

### pytools.sh — Python Tools Installer

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh | BFS_VER=$BFS_VER bash
```

Installs Python CLI tools to `~/pytools` and adds them to `PATH`.

**Menu**
- **1** Install / Update
- **2** Uninstall
