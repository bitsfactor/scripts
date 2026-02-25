# BitsFactor Scripts

A collection of bootstrap scripts for developers. All scripts support **macOS** and **Linux**, and run independently via `curl | bash`.

## env.sh — Development Environment Setup

One-command setup for a complete development environment on any fresh macOS or Linux machine. Installs Homebrew, Git, Python3, Node.js, Go, and a global Python tools directory — each as an independent option or all at once.

- **1) Install All** — Runs every step below in sequence: Homebrew (macOS) → Git → Python3 → Node.js → Go → PyTools Dir. Safe to re-run; already-installed tools are skipped.
- **2) Install Homebrew** — macOS only. Installs Homebrew if not present. Skipped silently on Linux.
- **3) Install Git** — Installs Git via Homebrew (macOS) or `apt-get` (Linux).
- **4) Install Python3** — Installs Python3 + pip + venv via Homebrew (macOS) or `apt-get` (Linux).
- **5) Install Node.js & npm** — Installs Node via Homebrew (macOS) or nvm LTS (Linux). Writes nvm init block to shell config.
- **6) Install Go** — Installs Go via Homebrew (macOS) or downloads the official SDK to `~/.go_sdk` (Linux, no sudo required). Writes `GOROOT`/`PATH` to shell config.
- **7) Setup Python Global Tools Dir** — Creates `~/pytools` and adds it to `PATH`. Drop any executable Python script there and call it by name from anywhere.

```bash
curl -s https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/env.sh | bash
```

```bash
curl -s https://gcore.jsdelivr.net/gh/bitsfactor/scripts@main/env.sh | bash
```

```bash
curl -s https://ghproxy.net/https://raw.githubusercontent.com/bitsfactor/scripts/main/env.sh | bash
```

## git.sh — SSH Key Manager

The fastest way to set up GitHub SSH access across all your machines. Designed for solo developers who manage multiple VPS instances — generate a key pair once on your main computer, then share the same private key to every new server. No more repeated key generation or manual config.

- **1) Retrieve Keys** — Run on your main computer. Gets your SSH key pair (or generates one if none exists) and copies the private key to clipboard. Add the public key to [GitHub SSH Settings](https://github.com/settings/keys) once.
- **2) Set Key** — Run on any new VPS or Mac. Paste your private key and the script handles the rest. Once done, you can `git clone` private repos immediately.

```bash
curl -s https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/git.sh | bash
```

```bash
curl -s https://gcore.jsdelivr.net/gh/bitsfactor/scripts@main/git.sh | bash
```

```bash
curl -s https://ghproxy.net/https://raw.githubusercontent.com/bitsfactor/scripts/main/git.sh | bash
```

## claude.sh — Claude Code Setup

Install / update, configure, or uninstall Claude Code.

- **1) Install / Update** — Install Claude Code, or update it if already installed. Automatically detects the install method (npm, Homebrew, official installer) and runs the matching upgrade command.
- **2) Set API** — Enter your API endpoint and key. The script saves them and cleans up any old config automatically.
- **3) Uninstall** — Remove Claude Code and all its config files. You can also choose to only clear config while keeping the program.

```bash
curl -s https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/claude.sh | bash
```

```bash
curl -s https://gcore.jsdelivr.net/gh/bitsfactor/scripts@main/claude.sh | bash
```

```bash
curl -s https://ghproxy.net/https://raw.githubusercontent.com/bitsfactor/scripts/main/claude.sh | bash
```
