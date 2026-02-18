# BitsFactor Scripts

Quick bootstrap scripts for local and remote VPS environment setup.
本地机器和远程 VPS 的快速引导脚本集合。

> **🔑 Architecture Concept / 架构理念:**
> * **Configure Once / 一次配置:** Add the generated **Public Key** (.pub) to your GitHub SSH Settings (github.com/settings/keys) exactly once. 将生成的公钥添加到 GitHub SSH 设置，只需一次。
> * **Sync Everywhere / 处处同步:** Use the exact same **Private Key** across all your devices and VPS instances to instantly grant them identical GitHub access permissions. 在所有设备和 VPS 上使用同一私钥，即可获得相同的 GitHub 访问权限。

## 1. Local Machine: Retrieve Keys / 本地机器: 获取密钥

Run this on your local machine (e.g., Mac) to get your SSH key pair.
在本地机器（如 Mac）上运行，获取 SSH 密钥对。

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git/get-key.sh | bash
```

## 2. Remote Server / Mac: Set SSH Key / 远程服务器 / Mac: 配置 SSH 密钥

Run this on any newly provisioned VPS or Mac, then paste your **Private Key** when prompted.
在新开通的 VPS 或 Mac 上运行，按提示粘贴私钥。

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git/set-key.sh | bash
```

## 3. Clear Claude Code Settings / 清除 Claude Code 配置

Run this to completely remove Claude Code CLI configurations, cache, and optionally uninstall the program.
彻底清除 Claude Code CLI 的所有配置、缓存，并可选择卸载程序。

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude/clear.sh | bash
```

## 4. Set Claude Code API / 配置 Claude Code API

Run this to configure Claude Code API settings. It writes all config to `~/.zshrc` and cleans up stale entries from other locations.
配置 Claude Code 的 API 设置。将所有配置统一写入 `~/.zshrc`，并清理其他位置的残留配置。

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude/set-api.sh | bash
```
