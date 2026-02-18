# BitsFactor Scripts

Quick bootstrap scripts for local and remote VPS environment setup.

> **🔑 Architecture Concept:**
> * **Configure Once:** Add the generated **Public Key** (.pub) to your GitHub SSH Settings (github.com/settings/keys) exactly once.
> * **Sync Everywhere:** Use the exact same **Private Key** across all your devices and VPS instances to instantly grant them identical GitHub access permissions.

## 1. Local Machine: Retrieve Keys

Run this on your local machine (e.g., Mac) to get your SSH key pair:

```bash
curl -s [https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh](https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh) | bash
```

## 2. Remote Server / Mac: Set SSH Key

Run this on any newly provisioned VPS or Mac, then paste your **Private Key** when prompted:

```bash
curl -s [https://raw.githubusercontent.com/bitsfactor/scripts/main/git/set-key.sh](https://raw.githubusercontent.com/bitsfactor/scripts/main/git/set-key.sh) | bash
```
