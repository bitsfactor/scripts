# BitsFactor Scripts

Quick bootstrap scripts for local and remote VPS environment setup.

> **🔑 Key Concept:**
> * **Public Key (`.pub`):** Add this to your [GitHub SSH Settings](https://github.com/settings/keys).
> * **Private Key:** Keep this secret. You will paste this into your VPS.

## 1. Local Machine: Get Keys

Run this on your local machine (e.g., Mac). It will automatically copy the **Private Key** to your clipboard and display the **Public Key** for GitHub:

```bash
bash <(curl -s [https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh](https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh))
```

## 2. Remote Server: Init GitHub Auth

Run this on your newly provisioned VPS, then paste your **Private Key** when prompted to instantly configure GitHub access:

```bash
bash <(curl -s [https://raw.githubusercontent.com/bitsfactor/scripts/main/git/init.sh](https://raw.githubusercontent.com/bitsfactor/scripts/main/git/init.sh))
```
