# BitsFactor Scripts

Quick bootstrap scripts for local and remote VPS environment setup.

## 1. Local Machine: Get SSH Key

Run this on your local machine (e.g., Mac) to generate or copy your SSH private key to the clipboard:

```bash
bash <(curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh)
```

## 2. Remote Server: Init GitHub Auth

Run this on your newly provisioned VPS, then paste the key when prompted to configure GitHub access:

```bash
bash <(curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git/init.sh)
```
