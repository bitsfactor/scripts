# BitsFactor Scripts

A collection of bootstrap scripts for developers. All scripts support **macOS** and **Linux**, and run independently via `curl | bash`. All scripts share a single version number defined in `version.sh`.

## Quick Start

**jsDelivr CDN**:
```bash
curl -s https://fastly.jsdelivr.net/gh/bitsfactor/scripts@latest/<script> | bash
```

**GitHub Raw** (always latest):
```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/<script> | bash
```

## one.sh — One-Click VPS Setup

One command to fully initialize a new VPS. Downloads and orchestrates `env.sh`, `git.sh`, and `claude.sh` in sequence — each step asks for confirmation before running, so you can skip anything you don't need.

- **Step 1** Install dev tools (env.sh install-all)
- **Step 2** Set SSH private key (git.sh set-key)
- **Step 3** Install Claude Code (claude.sh install)
- **Step 4** Configure API (claude.sh set-api)
- **Step 5** Trust All Tools (claude.sh trust-all) — Linux only

## env.sh — Development Environment Setup

One-command setup for a complete development environment on any fresh macOS or Linux machine. Installs Homebrew, Git, Python3, Node.js, and Go — each as an independent option or all at once.

- **1) Install All** — Runs every step below in sequence: Homebrew (macOS) → Git → Python3 → Node.js → Go. Safe to re-run; already-installed tools are skipped.
- **2) Install Homebrew** — macOS only. Installs Homebrew if not present. Skipped silently on Linux.
- **3) Install Git** — Installs Git via Homebrew (macOS) or `apt-get` (Linux).
- **4) Install Python3** — Installs Python3 + pip + venv via Homebrew (macOS) or `apt-get` (Linux).
- **5) Install Node.js & npm** — Installs Node via Homebrew (macOS) or nvm LTS (Linux). Writes nvm init block to shell config.
- **6) Install Go** — Installs Go via Homebrew (macOS) or downloads the official SDK to `~/.go_sdk` (Linux, no sudo required). Writes `GOROOT`/`PATH` to shell config.
- **7) Install / Update OOSP** — Fetch OOSP spec from CDN and append to `~/.claude/CLAUDE.md` or project-level `CLAUDE.md`. Supports Chinese and English.

## git.sh — SSH Key Manager

The fastest way to set up GitHub SSH access across all your machines. Designed for solo developers who manage multiple VPS instances — generate a key pair once on your main computer, then share the same private key to every new server. No more repeated key generation or manual config.

- **1) Retrieve Keys** — Run on your main computer. Gets your SSH key pair (or generates one if none exists) and copies the private key to clipboard. Add the public key to [GitHub SSH Settings](https://github.com/settings/keys) once.
- **2) Set Key** — Run on any new VPS or Mac. Paste your private key and the script handles the rest. Once done, you can `git clone` private repos immediately.

## claude.sh — Claude Code Setup

Install / update, configure, or uninstall Claude Code.

- **1) Install / Update** — Install Claude Code, or update it if already installed. Automatically detects the install method (npm, Homebrew, official installer) and runs the matching upgrade command.
- **2) Set API** — Enter your API endpoint and key. The script saves them and cleans up any old config automatically.
- **3) Trust All Tools** — Skip all permission prompts.
- **4) Uninstall** — Remove Claude Code and all its config files. You can also choose to only clear config while keeping the program.

## pytools.sh — Python Tools Installer

One-click deploy Python command-line tools to `~/pytools`. Downloads each tool from CDN, installs Python dependencies, and adds `~/pytools` to `PATH` — so every tool is callable by name from anywhere in the terminal.

- **1) Install / Update** — Downloads all Python tools to `~/pytools`, installs required dependencies into an isolated virtual environment (`~/pytools/.venv/`), and writes the `~/pytools` PATH block to your shell config.
- **2) Uninstall** — Removes the `~/pytools/` directory and cleans up the PATH block from all shell config files.
