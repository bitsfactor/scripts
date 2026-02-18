# BitsFactor Scripts

A collection of bootstrap scripts. Each script runs independently via `curl | bash`.

## git.sh — SSH Key Manager

Manage SSH keys for GitHub authentication across local machines and remote servers. Based on a **"configure once, sync everywhere"** workflow: generate a key pair once, add the public key to GitHub, then distribute the same private key to all your devices.

- **1) Retrieve Keys** — Detect an existing SSH key (ed25519 preferred, RSA fallback) or generate a new ed25519 key pair. Prints both keys to the terminal and copies the private key to clipboard.
- **2) Set Key** — Paste a private key onto a new server or Mac. Sets correct permissions (700/600), regenerates the matching public key, adds GitHub to `known_hosts`, and verifies the connection.

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git.sh | bash
```

## claude.sh — Claude Code Setup

Install, configure, or uninstall Claude Code on macOS and Linux.

- **1) Install** — Download and run the official installer (`https://claude.ai/install.sh`).
- **2) Set API** — Prompt for `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`, clean any stale config from shell profiles and `~/.claude/settings.json`, then write a managed block to `~/.zshrc`.
- **3) Uninstall** — Auto-detect install method (npm / Homebrew / official installer), offer full uninstall or config-only cleanup, remove all related files (`~/.claude/`, `~/.claude.json`, cache, shell env vars), and verify results.

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude.sh | bash
```
