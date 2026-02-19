# BitsFactor Scripts

A collection of bootstrap scripts for developers. All scripts support **macOS** and **Linux**, and run independently via `curl | bash`.

## git.sh — SSH Key Manager

The fastest way to set up GitHub SSH access across all your machines. Designed for solo developers who manage multiple VPS instances — generate a key pair once on your main computer, then share the same private key to every new server. No more repeated key generation or manual config.

- **1) Retrieve Keys** — Run on your main computer. Gets your SSH key pair (or generates one if none exists) and copies the private key to clipboard. Add the public key to [GitHub SSH Settings](https://github.com/settings/keys) once.
- **2) Set Key** — Run on any new VPS or Mac. Paste your private key and the script handles the rest. Once done, you can `git clone` private repos immediately.

```bash
curl -s https://cdn.jsdelivr.net/gh/bitsfactor/scripts@main/git.sh | bash
```

## claude.sh — Claude Code Setup

Install, configure, or uninstall Claude Code.

- **1) Install** — Install Claude Code with one click.
- **2) Set API** — Enter your API endpoint and key. The script saves them and cleans up any old config automatically.
- **3) Uninstall** — Remove Claude Code and all its config files. You can also choose to only clear config while keeping the program.

```bash
curl -s https://cdn.jsdelivr.net/gh/bitsfactor/scripts@main/claude.sh | bash
```
