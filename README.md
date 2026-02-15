# BitsFactor Scripts

A collection of utility scripts designed for maximum developer efficiency, server automation, and fast infrastructure bootstrapping.

---

## 🔑 SSH Key Retrieval (`get-key.sh`)

**Path:** `git/get-key.sh`

This script is designed to be run on your **local machine** (e.g., your Mac). It quickly retrieves your local SSH private key and copies it directly to your system clipboard, preparing you for lightning-fast VPS initialization.

### ✨ Features
* **Zero Dependencies:** Runs natively in Bash.
* **Smart Detection:** Auto-detects existing `id_ed25519` or `id_rsa` keys.
* **Auto-Generation:** Interactively prompts to generate a highly secure `ed25519` key if no keys are found.
* **Visual Clarity:** Prints both the Public Key (for GitHub) and Private Key (for your VPS) clearly on the screen.
* **Cross-Platform Clipboard:** Automatically copies the Private Key to your clipboard using macOS (`pbcopy`), Linux (`xclip` / `wl-copy`), or Windows WSL (`clip.exe`).

### 🚀 Usage

Run the following command in your local terminal:

```bash
bash <(curl -s [https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh](https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh))
