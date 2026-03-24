# BitsFactor Scripts

Lightweight bootstrap scripts for fresh Macs, Linux machines, and VPS instances.

<p align="center">
  <strong>One version · Standalone scripts · curl | bash friendly</strong>
</p>

## Quick Start

```bash
BFS_VER=1.3.12
```

Use any script with the same pattern:

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/<script>.sh | BFS_VER=$BFS_VER bash
```

## Script Index

| Script | Purpose | Run |
| --- | --- | --- |
| `one.sh` | Full guided VPS setup | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh &#124; BFS_VER=$BFS_VER bash |
| `env.sh` | Dev environment setup | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh &#124; BFS_VER=$BFS_VER bash |
| `git.sh` | GitHub SSH key setup | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh &#124; BFS_VER=$BFS_VER bash |
| `claude.sh` | Claude Code install + config | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh &#124; BFS_VER=$BFS_VER bash |
| `codex.sh` | Codex install + config | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/codex.sh &#124; BFS_VER=$BFS_VER bash |
| `pytools.sh` | Python CLI tools | BFS_VER=1.3.12;<br>curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh &#124; BFS_VER=$BFS_VER bash |

> Tip: the table is for quick copy. Each section below also has its own code block with GitHub's copy button.

---

## one.sh — One-Click VPS Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/one.sh | BFS_VER=$BFS_VER bash
```

For a brand-new VPS.

- Install dev tools
- Set SSH key
- Choose **Claude Code** or **Codex**
- Run the matching API setup flow

---

## env.sh — Development Environment Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/env.sh | BFS_VER=$BFS_VER bash
```

For a fresh machine.

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

For reusing one SSH key across machines.

**Menu**
- Retrieve keys
- Set key

---

## claude.sh — Claude Code Setup

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh | BFS_VER=$BFS_VER bash
```

For Claude Code install and API setup.

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

For Codex install and third-party API setup.

**Menu**
- Install Codex
- Configure API

---

## pytools.sh — Python Tools Installer

```bash
BFS_VER=1.3.12; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/pytools.sh | BFS_VER=$BFS_VER bash
```

For installing CLI Python tools into `~/pytools`.

**Menu**
- Install / Update
- Uninstall
