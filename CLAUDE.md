# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

BitsFactor Scripts 是一组 bash 引导脚本，用于本地机器和远程 VPS 的 SSH 密钥管理与 GitHub 认证。遵循"一次配置，处处同步"的模式。

## 仓库结构

```
version.sh    # 统一版本号来源（所有脚本运行时自动加载）
one.sh        # 一键式 VPS 初始化编排脚本（依次调用 env/git/claude，四步完成）
env.sh        # 开发环境配置工具（Brew / Git / Python3 / Node.js / Go）
git.sh        # Git SSH 密钥管理工具（获取密钥 / 配置密钥，二合一菜单）
claude.sh     # Claude Code 设置工具（安装 / 配置 API / 卸载，三合一菜单）
pytools.sh    # Python 命令行工具一键部署（安装到 ~/pytools，自动加 PATH）
```

项目无构建系统、包管理器或测试框架。脚本为独立的 bash 文件，可直接运行或通过 `curl | bash` 从 jsDelivr CDN 远程执行。

## 运行脚本

```bash
# 本地执行
bash one.sh
bash env.sh
bash git.sh
bash claude.sh
bash pytools.sh

# 远程执行（主要使用方式，具体版本号见 README.md）
BFS_VER=<ver>; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/<script>.sh | BFS_VER=$BFS_VER bash
```

## 脚本规范

- 使用 `set -e` 实现快速失败的错误处理
- 使用 ANSI 颜色编码输出用户提示（蓝色=信息，绿色=成功，黄色=警告，红色=错误）
- 跨平台剪贴板支持（macOS `pbcopy`、Linux `xclip`/`wl-copy`、Windows `clip.exe`）
- SSH 密钥类型优先级：ed25519 优先，RSA 作为备选
- 所有脚本必须同时支持 macOS 和 Linux（尤其是 Debian 和 Ubuntu 系统）

## 发布流程

当用户说"发布"时，执行以下步骤：

1. 从 `version.sh` 读取当前版本号
2. patch 版本 +1（如 1.3.1 → 1.3.2），写回 `version.sh`
3. 同步新版本号到 `README.md`（`sed` 替换所有 `BFS_VER=x.y.z;`）
4. 提交、打 tag、推送：
   ```bash
   git add -A && git commit -m "chore: bump version to $VER"
   git tag "v$VER" && git push && git push --tags
   ```

每个 tag 在 jsdelivr 上不可变，无需清除 CDN 缓存。
