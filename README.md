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

## 3. Claude Code Setup / Claude Code 设置工具

All-in-one menu for Claude Code: install, configure API, or uninstall.
Claude Code 三合一工具：安装、配置 API、卸载清理。

```bash
curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude/setup.sh | bash
```
