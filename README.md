# BitsFactor Scripts

Quick bootstrap scripts for local and remote VPS environment setup.

> **Architecture Concept:**
> * **Configure Once:** Add the generated **Public Key** (.pub) to your GitHub SSH Settings (github.com/settings/keys) exactly once.
> * **Sync Everywhere:** Use the exact same **Private Key** across all your devices and VPS instances to instantly grant them identical GitHub access permissions.

## 1. Git SSH Key Manager

Interactive menu for SSH key management and GitHub authentication.

- **1) Retrieve Keys** — Detect or generate an SSH key pair on your local machine, copy the private key to clipboard
- **2) Set Key** — Paste your private key on a remote server or Mac, configure permissions, and verify GitHub connection

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git.sh | bash
```

## 2. Claude Code Setup

Interactive menu for Claude Code management.

- **1) Install** — Download and install via the official installer
- **2) Set API** — Configure `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` in `~/.zshrc`
- **3) Uninstall** — Detect install method (npm / Homebrew / other), remove the binary and all config files

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude.sh | bash
```
