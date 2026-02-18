# BitsFactor Scripts

Quick bootstrap scripts for local and remote VPS environment setup.

> **Architecture Concept:**
> * **Configure Once:** Add the generated **Public Key** (.pub) to your GitHub SSH Settings (github.com/settings/keys) exactly once.
> * **Sync Everywhere:** Use the exact same **Private Key** across all your devices and VPS instances to instantly grant them identical GitHub access permissions.

## 1. Retrieve SSH Keys (Local Machine)

Run this on your local machine (e.g., Mac) to detect or generate an SSH key pair and copy it to the clipboard.

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh | bash
```

## 2. Set SSH Key (Remote Server / Mac)

Run this on any newly provisioned VPS or Mac, then paste your **Private Key** when prompted.

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git/set-key.sh | bash
```

## 3. Claude Code Setup

All-in-one menu for Claude Code: install, configure API, or uninstall.

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude/setup.sh | bash
```
