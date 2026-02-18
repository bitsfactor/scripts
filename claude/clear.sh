#!/bin/bash

# =============================================================================
# Claude Code 清理脚本
# 用途: 彻底清除 Claude Code CLI 的所有配置和设置项
# 支持检测 NPM / Homebrew / 手动安装方式，并执行对应的卸载和清理操作
#
# 使用方式:
#   bash claude/clear.sh
#   curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude/clear.sh | bash
# =============================================================================

set -e

# 颜色定义
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

echo -e "${BLUE}=== Claude Code 清理工具 ===${NC}"

# ---- Step 1/7: 检测操作系统 ----
echo -e "\n${BLUE}[Step 1/7] 检测操作系统...${NC}"

OS_TYPE=""
case "$OSTYPE" in
    darwin*)  OS_TYPE="macos" ;;
    linux*)   OS_TYPE="linux" ;;
    *)
        echo -e "${RED}[Error] 不支持的操作系统: $OSTYPE${NC}"
        echo -e "${YELLOW}此脚本仅支持 macOS 和 Linux.${NC}"
        exit 1
        ;;
esac
echo -e "检测到系统: ${CYAN}${OS_TYPE}${NC}"

# ---- Step 2/7: 检测 Claude Code 安装方式 ----
echo -e "\n${BLUE}[Step 2/7] 检测 Claude Code 安装方式...${NC}"

INSTALL_METHOD=""

# 检测 NPM 全局安装
if command -v npm &> /dev/null && npm list -g @anthropic-ai/claude-code 2>/dev/null | grep -q "claude-code"; then
    INSTALL_METHOD="npm"
    echo -e "检测到安装方式: ${CYAN}NPM 全局安装${NC}"
# 检测 Homebrew cask（仅 macOS）
elif [ "$OS_TYPE" = "macos" ] && command -v brew &> /dev/null && brew list --cask claude-code 2>/dev/null | grep -q "."; then
    INSTALL_METHOD="homebrew"
    echo -e "检测到安装方式: ${CYAN}Homebrew Cask${NC}"
# 检测其他方式（官方安装器 / 手动安装）
elif command -v claude &> /dev/null; then
    INSTALL_METHOD="other"
    CLAUDE_PATH=$(which claude 2>/dev/null || true)
    echo -e "检测到安装方式: ${CYAN}官方安装器 / 手动安装${NC}"
    echo -e "可执行文件路径: ${YELLOW}${CLAUDE_PATH}${NC}"
else
    echo -e "${YELLOW}[Notice] 未检测到 Claude Code 安装.${NC}"
fi

# ---- Step 3/7: 扫描待清理项 ----
echo -e "\n${BLUE}[Step 3/7] 扫描待清理项...${NC}"

ITEMS_TO_CLEAN=()

# ~/.claude/ 目录
if [ -d "$HOME/.claude" ]; then
    ITEMS_TO_CLEAN+=("$HOME/.claude")
    echo -e "  📁 ${YELLOW}~/.claude/${NC} (配置、缓存、插件等)"
fi

# ~/.claude.json
if [ -f "$HOME/.claude.json" ]; then
    ITEMS_TO_CLEAN+=("$HOME/.claude.json")
    echo -e "  📄 ${YELLOW}~/.claude.json${NC}"
fi

# ~/.claude.json.backup*
BACKUP_FILES=$(ls "$HOME"/.claude.json.backup* 2>/dev/null || true)
if [ -n "$BACKUP_FILES" ]; then
    for bf in $BACKUP_FILES; do
        ITEMS_TO_CLEAN+=("$bf")
        echo -e "  📄 ${YELLOW}~/${bf##*/}${NC}"
    done
fi

# ~/.anthropic-api-key
if [ -f "$HOME/.anthropic-api-key" ]; then
    ITEMS_TO_CLEAN+=("$HOME/.anthropic-api-key")
    echo -e "  🔑 ${YELLOW}~/.anthropic-api-key${NC}"
fi

# macOS 缓存目录
if [ "$OS_TYPE" = "macos" ] && [ -d "$HOME/Library/Caches/claude-cli-nodejs" ]; then
    ITEMS_TO_CLEAN+=("$HOME/Library/Caches/claude-cli-nodejs")
    echo -e "  📁 ${YELLOW}~/Library/Caches/claude-cli-nodejs/${NC}"
fi

# 如果什么都没找到且未安装
if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ] && [ -z "$INSTALL_METHOD" ]; then
    echo -e "\n${GREEN}[Success] 系统中未发现 Claude Code 的任何安装或配置文件.${NC}"
    echo -e "无需清理，退出."
    exit 0
fi

if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ]; then
    echo -e "  ${YELLOW}(未发现配置文件)${NC}"
fi

# ---- Step 4/7: 用户确认 ----
echo -e "\n${BLUE}[Step 4/7] 请确认操作...${NC}"

USER_CHOICE=""

if [ -n "$INSTALL_METHOD" ]; then
    echo -e "${CYAN}请选择操作:${NC}"
    echo -e "  ${GREEN}1)${NC} 完整卸载 + 清除所有配置"
    echo -e "  ${YELLOW}2)${NC} 仅清除配置文件（保留程序）"
    echo -e "  ${RED}0)${NC} 取消"
    echo ""
    read -p "👉 请输入选项 (0/1/2): " USER_CHOICE < /dev/tty

    case "$USER_CHOICE" in
        1) echo -e "${BLUE}已选择: 完整卸载 + 清除配置${NC}" ;;
        2) echo -e "${BLUE}已选择: 仅清除配置文件${NC}" ;;
        0|"")
            echo -e "${RED}[Cancelled] 操作已取消.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[Error] 无效的选项: $USER_CHOICE${NC}"
            exit 1
            ;;
    esac
else
    echo -e "将清除以上列出的 ${CYAN}${#ITEMS_TO_CLEAN[@]}${NC} 个配置项."
    read -p "👉 确认清除? (y/n): " CONFIRM < /dev/tty
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[Cancelled] 操作已取消.${NC}"
        exit 0
    fi
    USER_CHOICE="2"
fi

# ---- Step 5/7: 卸载程序（条件执行）----
UNINSTALL_SUCCESS=true

if [ "$USER_CHOICE" = "1" ]; then
    echo -e "\n${BLUE}[Step 5/7] 卸载 Claude Code 程序...${NC}"

    case "$INSTALL_METHOD" in
        npm)
            echo -e "正在通过 NPM 卸载..."
            if npm uninstall -g @anthropic-ai/claude-code 2>/dev/null; then
                echo -e "${GREEN}[Success] NPM 卸载完成.${NC}"
            else
                echo -e "${YELLOW}[Warning] NPM 普通卸载失败，尝试 sudo...${NC}"
                if sudo npm uninstall -g @anthropic-ai/claude-code 2>/dev/null; then
                    echo -e "${GREEN}[Success] NPM 卸载完成 (sudo).${NC}"
                else
                    echo -e "${RED}[Error] NPM 卸载失败.${NC}"
                    UNINSTALL_SUCCESS=false
                fi
            fi
            ;;
        homebrew)
            echo -e "正在通过 Homebrew 卸载..."
            if brew uninstall --cask claude-code 2>/dev/null; then
                echo -e "${GREEN}[Success] Homebrew 卸载完成.${NC}"
            else
                echo -e "${RED}[Error] Homebrew 卸载失败.${NC}"
                UNINSTALL_SUCCESS=false
            fi
            ;;
        other)
            echo -e "正在删除可执行文件..."
            CLAUDE_BIN=$(which claude 2>/dev/null || true)
            REMOVED_BIN=false

            # 尝试删除 which claude 指向的路径
            if [ -n "$CLAUDE_BIN" ]; then
                if rm "$CLAUDE_BIN" 2>/dev/null || sudo rm "$CLAUDE_BIN" 2>/dev/null; then
                    echo -e "${GREEN}[Success] 已删除 ${CLAUDE_BIN}${NC}"
                    REMOVED_BIN=true
                else
                    echo -e "${RED}[Error] 无法删除 ${CLAUDE_BIN}${NC}"
                fi
            fi

            # 尝试删除 ~/.local/bin/claude
            if [ -f "$HOME/.local/bin/claude" ]; then
                if rm "$HOME/.local/bin/claude" 2>/dev/null; then
                    echo -e "${GREEN}[Success] 已删除 ~/.local/bin/claude${NC}"
                    REMOVED_BIN=true
                else
                    echo -e "${RED}[Error] 无法删除 ~/.local/bin/claude${NC}"
                fi
            fi

            if [ "$REMOVED_BIN" = false ]; then
                echo -e "${RED}[Error] 未能删除任何可执行文件.${NC}"
                UNINSTALL_SUCCESS=false
            fi
            ;;
    esac
else
    echo -e "\n${BLUE}[Step 5/7] 跳过卸载（保留程序）.${NC}"
fi

# ---- Step 6/7: 清除配置文件 ----
echo -e "\n${BLUE}[Step 6/7] 清除配置文件...${NC}"

DELETED_COUNT=0
FAILED_COUNT=0

for item in "${ITEMS_TO_CLEAN[@]}"; do
    DISPLAY_NAME="${item/#$HOME/~}"
    if rm -rf "$item" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} 已删除 ${DISPLAY_NAME}"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        if sudo rm -rf "$item" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} 已删除 ${DISPLAY_NAME} (sudo)"
            DELETED_COUNT=$((DELETED_COUNT + 1))
        else
            echo -e "  ${RED}✗${NC} 无法删除 ${DISPLAY_NAME}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi
done

if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ]; then
    echo -e "  ${YELLOW}(无配置文件需要清理)${NC}"
fi

# ---- Step 7/7: 验证结果 ----
echo -e "\n${BLUE}[Step 7/7] 验证清理结果...${NC}"

ALL_CLEAN=true

# 检查 claude 命令是否还存在（如果选了卸载）
if [ "$USER_CHOICE" = "1" ]; then
    if command -v claude &> /dev/null; then
        echo -e "  ${RED}✗${NC} claude 命令仍然存在: $(which claude)"
        ALL_CLEAN=false
    else
        echo -e "  ${GREEN}✓${NC} claude 命令已移除"
    fi
fi

# 检查配置目录和文件
if [ -d "$HOME/.claude" ]; then
    echo -e "  ${RED}✗${NC} ~/.claude/ 目录仍然存在"
    ALL_CLEAN=false
else
    echo -e "  ${GREEN}✓${NC} ~/.claude/ 已清除"
fi

if [ -f "$HOME/.claude.json" ]; then
    echo -e "  ${RED}✗${NC} ~/.claude.json 仍然存在"
    ALL_CLEAN=false
else
    echo -e "  ${GREEN}✓${NC} ~/.claude.json 已清除"
fi

# 输出统计
echo -e "\n${CYAN}========================================${NC}"
echo -e "  已删除: ${GREEN}${DELETED_COUNT}${NC} 项"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "  失败:   ${RED}${FAILED_COUNT}${NC} 项"
fi
if [ "$USER_CHOICE" = "1" ]; then
    if [ "$UNINSTALL_SUCCESS" = true ]; then
        echo -e "  程序:   ${GREEN}已卸载${NC}"
    else
        echo -e "  程序:   ${RED}卸载失败${NC}"
    fi
fi
echo -e "${CYAN}========================================${NC}"

if [ "$ALL_CLEAN" = true ] && [ $FAILED_COUNT -eq 0 ]; then
    echo -e "\n${GREEN}[Success] Claude Code 清理完成!${NC}"
    echo -e "🎉 所有配置和缓存已彻底清除."
else
    echo -e "\n${YELLOW}[Warning] 部分项目未能清理，请检查上方输出.${NC}"
fi
