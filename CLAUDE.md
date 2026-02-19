# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

BitsFactor Scripts 是一组 bash 引导脚本，用于本地机器和远程 VPS 的 SSH 密钥管理与 GitHub 认证。遵循"一次配置，处处同步"的模式。

## 仓库结构

```
git.sh        # Git SSH 密钥管理工具（获取密钥 / 配置密钥，二合一菜单）
claude.sh     # Claude Code 设置工具（安装 / 配置 API / 卸载，三合一菜单）
```

项目无构建系统、包管理器或测试框架。脚本为独立的 bash 文件，可直接运行或通过 `curl | bash` 从 jsDelivr CDN 远程执行。

## 运行脚本

```bash
# 本地执行
bash git.sh
bash claude.sh

# 远程执行（主要使用方式）
curl -s https://cdn.jsdelivr.net/gh/bitsfactor/scripts@main/git.sh | bash
curl -s https://cdn.jsdelivr.net/gh/bitsfactor/scripts@main/claude.sh | bash
```

## 脚本规范

- 使用 `set -e` 实现快速失败的错误处理
- 使用 ANSI 颜色编码输出用户提示（蓝色=信息，绿色=成功，黄色=警告，红色=错误）
- 跨平台剪贴板支持（macOS `pbcopy`、Linux `xclip`/`wl-copy`、Windows `clip.exe`）
- SSH 密钥类型优先级：ed25519 优先，RSA 作为备选
- 所有脚本必须同时支持 macOS 和 Linux（尤其是 Debian 和 Ubuntu 系统）
