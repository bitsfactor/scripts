# BitsFactor Scripts

Simple bootstrap scripts for fresh Macs, Linux machines, and VPS instances.

<p align="center">
  <strong>One version • Independent scripts • curl | bash friendly</strong>
</p>

## Quick Start

```bash
BFS_VER=1.3.12
```

Or run any script directly with the version inline:

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh | BFS_VER=$BFS_VER bash
```

## Scripts

| Script | What it does | Run |
| --- | --- | --- |
| `one.sh` | Guided VPS setup | BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh &#124; BFS_VER=$BFS_VER bash |
| `env.sh` | Install dev tools | BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh &#124; BFS_VER=$BFS_VER bash |
| `git.sh` | Set up GitHub SSH keys | BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh &#124; BFS_VER=$BFS_VER bash |
| `claude.sh` | Install and configure Claude Code | BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh &#124; BFS_VER=$BFS_VER bash |
| `codex.sh` | Install and configure Codex | BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh &#124; BFS_VER=$BFS_VER bash |
| `pytools.sh` | Install Python CLI tools | BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh &#124; BFS_VER=$BFS_VER bash |

---

## one.sh — One-Click VPS Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh | BFS_VER=$BFS_VER bash
```

Best for a brand-new VPS.

- Installs dev tools
- Sets SSH key
- Lets you choose **Claude Code** or **Codex**
- Runs the matching API setup flow

---

## env.sh — Development Environment Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh | BFS_VER=$BFS_VER bash
```

Best for a fresh machine.

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

Best for syncing one SSH key across machines.

**Menu**
- Retrieve keys
- Set key

---

## claude.sh — Claude Code Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh | BFS_VER=$BFS_VER bash
```

Best for Claude Code install and API setup.

**Menu**
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

Best for Codex install and third-party API setup.

**Menu**
- Install Codex
- Configure API

---

## pytools.sh — Python Tools Installer

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh | BFS_VER=$BFS_VER bash
```

Best for installing CLI Python tools into `~/pytools`.

**Menu**
- Install / Update
- Uninstall
