# BitsFactor Scripts

> Small bootstrap scripts for fresh Macs, Linux machines, and VPS instances.

<p align="center">
  <strong>One version · Standalone scripts · curl | bash friendly</strong>
</p>

## Quick Start

```bash
BFS_VER=1.3.12
```

Shared pattern for every script:

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/<script>.sh | BFS_VER=$BFS_VER bash
```

## At a Glance

Copy any command in the table directly.

| Script | Purpose | Run |
| --- | --- | --- |
| `one.sh` | New VPS setup | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh &#124; BFS_VER=$BFS_VER bash |
| `env.sh` | Dev environment | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh &#124; BFS_VER=$BFS_VER bash |
| `git.sh` | GitHub SSH keys | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh &#124; BFS_VER=$BFS_VER bash |
| `claude.sh` | Claude Code | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh &#124; BFS_VER=$BFS_VER bash |
| `codex.sh` | Codex | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh &#124; BFS_VER=$BFS_VER bash |
| `pytools.sh` | Python CLI tools | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh &#124; BFS_VER=$BFS_VER bash |

---

## one.sh — One-Click VPS Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh | BFS_VER=$BFS_VER bash
```

Use this on a brand-new VPS.

**Flow**
- Install dev tools
- Set SSH key
- Choose **Claude Code** or **Codex**
- Run the matching API setup flow

---

## env.sh — Development Environment Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh | BFS_VER=$BFS_VER bash
```

Use this on a fresh machine.

**Includes**
- Homebrew — macOS only
- Git
- Python3
- Node.js & npm
- Go
- Docker
- SSH port change — Linux only

---

## git.sh — SSH Key Manager

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh | BFS_VER=$BFS_VER bash
```

Use this to reuse one SSH key across machines.

**Main actions**
- Retrieve keys
- Set key

---

## claude.sh — Claude Code Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh | BFS_VER=$BFS_VER bash
```

Use this to install and configure Claude Code.

**Main actions**
- Install / Update
- Set API
- Trust All Tools
- Install / Update oosp
- Uninstall

---

## codex.sh — Codex Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh | BFS_VER=$BFS_VER bash
```

Use this to install Codex and set a third-party API.

**Main actions**
- Install Codex
- Configure API

---

## pytools.sh — Python Tools Installer

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh | BFS_VER=$BFS_VER bash
```

Use this to install CLI Python tools into `~/pytools`.

**Main actions**
- Install / Update
- Uninstall
