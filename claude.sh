#!/bin/bash

# =============================================================================
# Claude Code 设置工具（整合入口）
# 用途: 提供统一菜单，支持安装 Claude Code、配置 API、卸载清理三合一操作
# 支持 macOS 和 Linux（Debian / Ubuntu）
#
# 使用方式:
#   bash claude.sh
#   curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude.sh | bash
# =============================================================================

set -e

# 颜色定义
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

# ---- 公共: 检测操作系统 ----

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

# =============================================================================
# 功能 1: 安装 Claude Code
# =============================================================================

do_install() {
    echo -e "\n${BLUE}=== 安装 Claude Code ===${NC}"
    echo -e "检测到系统: ${CYAN}${OS_TYPE}${NC}\n"

    echo -e "${BLUE}正在通过官方安装器安装 Claude Code...${NC}\n"

    local tmp_installer
    tmp_installer=$(mktemp)
    if ! curl -fsSL https://claude.ai/install.sh -o "$tmp_installer"; then
        echo -e "${RED}[Error] 下载安装脚本失败.${NC}"
        rm -f "$tmp_installer"
        return 1
    fi
    bash "$tmp_installer"
    rm -f "$tmp_installer"

    echo -e "\n${GREEN}[Success] Claude Code 安装完成!${NC}"
}

# =============================================================================
# 功能 2: 设置 API
# 复用 set-api.sh 的全部逻辑
# =============================================================================

do_set_api() {
    echo -e "\n${BLUE}=== Claude Code API 配置 ===${NC}"
    echo -e "检测到系统: ${CYAN}${OS_TYPE}${NC}"

    # 需要清理的变量列表
    local CLEAN_VARS=("ANTHROPIC_BASE_URL" "ANTHROPIC_AUTH_TOKEN" "ANTHROPIC_API_KEY" "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" "API_TIMEOUT_MS")

    # 标记块标识
    local BLOCK_START="# >>> Claude Code API"
    local BLOCK_END="# <<< Claude Code API"

    # ---- 提示用户输入 ----
    echo -e "\n${BLUE}[Step 1/4] 请输入 API 配置信息...${NC}"

    echo -e "${CYAN}请输入 ANTHROPIC_BASE_URL (API 地址):${NC}"
    read -r INPUT_URL < /dev/tty

    if [ -z "$INPUT_URL" ]; then
        echo -e "${RED}[Error] API 地址不能为空.${NC}"
        return 1
    fi

    echo -e "${CYAN}请输入 ANTHROPIC_AUTH_TOKEN (API Key，输入时不会显示):${NC}"
    read -rs INPUT_TOKEN < /dev/tty
    echo ""

    if [ -z "$INPUT_TOKEN" ]; then
        echo -e "${RED}[Error] API Key 不能为空.${NC}"
        return 1
    fi

    echo -e "${GREEN}输入完成.${NC}"

    # ---- 扫描并清理旧配置 ----
    echo -e "\n${BLUE}[Step 2/4] 扫描并清理旧配置...${NC}"

    # sed_inplace: 跨平台 sed -i 封装
    # 参数: $1 = sed 表达式, $2 = 文件路径
    sed_inplace() {
        if [ "$OS_TYPE" = "macos" ]; then
            sed -i '' "$1" "$2"
        else
            sed -i "$1" "$2"
        fi
    }

    # clean_shell_config: 清理单个 shell 配置文件
    # 参数: $1 = 文件路径
    clean_shell_config() {
        local file="$1"
        if [ ! -f "$file" ]; then
            return
        fi

        local display_name="${file/#$HOME/~}"
        local cleaned=false

        # 1) 删除标记块（从 BLOCK_START 到 BLOCK_END 之间的所有内容）
        if grep -q "$BLOCK_START" "$file" 2>/dev/null; then
            sed_inplace "/$BLOCK_START/,/$BLOCK_END/d" "$file"
            cleaned=true
        fi

        # 2) 删除标记块外散落的相关 export 行
        for var in "${CLEAN_VARS[@]}"; do
            if grep -q "^export ${var}=" "$file" 2>/dev/null; then
                sed_inplace "/^export ${var}=/d" "$file"
                cleaned=true
            fi
        done

        if [ "$cleaned" = true ]; then
            echo -e "  ${GREEN}✓${NC} 已清理 ${display_name}"
        fi
    }

    # clean_settings_json: 清理 ~/.claude/settings.json 中 env 字段的相关 key
    clean_settings_json() {
        local file="$HOME/.claude/settings.json"
        if [ ! -f "$file" ]; then
            return
        fi

        local cleaned=false

        for var in "${CLEAN_VARS[@]}"; do
            if grep -q "\"${var}\"" "$file" 2>/dev/null; then
                # 删除包含该变量名的行（匹配 "VAR_NAME": "..." 格式）
                grep -v "\"${var}\"" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
                cleaned=true
            fi
        done

        if [ "$cleaned" = true ]; then
            # 修复可能产生的 JSON 尾部逗号问题
            perl -0777 -i -pe 's/,(\s*[}\]])/\1/g' "$file" 2>/dev/null || true

            # 检查 env 对象是否为空，如果为空则删除整个 env 字段
            if grep -q '"env"' "$file" 2>/dev/null; then
                local env_content
                env_content=$(perl -0777 -ne 'if (/"env"\s*:\s*\{([^}]*)\}/) { print $1; }' "$file" 2>/dev/null || true)
                local trimmed
                trimmed=$(echo "$env_content" | tr -d '[:space:]')
                if [ -z "$trimmed" ]; then
                    perl -0777 -i -pe 's/,?\s*"env"\s*:\s*\{\s*\}//g' "$file" 2>/dev/null || true
                    perl -0777 -i -pe 's/,(\s*[}\]])/\1/g' "$file" 2>/dev/null || true
                fi
            fi

            echo -e "  ${GREEN}✓${NC} 已清理 ~/.claude/settings.json 中的 env 配置"
        fi
    }

    # 执行清理
    local SHELL_CONFIGS=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")

    for config in "${SHELL_CONFIGS[@]}"; do
        clean_shell_config "$config"
    done

    clean_settings_json

    echo -e "  ${GREEN}旧配置清理完成.${NC}"

    # ---- 写入新配置到 ~/.zshrc ----
    echo -e "\n${BLUE}[Step 3/4] 写入新配置到 ~/.zshrc...${NC}"

    # 确保 ~/.zshrc 存在
    touch "$HOME/.zshrc"

    # 写入标记块
    cat >> "$HOME/.zshrc" << EOF

# >>> Claude Code API 配置 (由 setup.sh 设置) >>>
export ANTHROPIC_BASE_URL='${INPUT_URL}'
export ANTHROPIC_AUTH_TOKEN='${INPUT_TOKEN}'
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
# <<< Claude Code API 配置 <<<
EOF

    echo -e "  ${GREEN}✓${NC} 已写入 ~/.zshrc"

    # ---- 验证并提醒 ----
    echo -e "\n${BLUE}[Step 4/4] 配置完成，请查看概要...${NC}"

    echo -e "\n${CYAN}========================================${NC}"
    echo -e "  已写入以下配置到 ~/.zshrc:"
    echo -e "  ${GREEN}ANTHROPIC_BASE_URL${NC}  = ${YELLOW}${INPUT_URL}${NC}"
    echo -e "  ${GREEN}ANTHROPIC_AUTH_TOKEN${NC} = ${YELLOW}******${NC}"
    echo -e "  ${GREEN}CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC${NC} = ${YELLOW}1${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "\n${GREEN}[Success] Claude Code API 配置完成!${NC}"
    echo -e "${YELLOW}[提醒] 请执行以下任一操作使配置生效:${NC}"
    echo -e "  1. 重新打开终端窗口"
    echo -e "  2. 手动执行: ${CYAN}source ~/.zshrc${NC}"
}

# =============================================================================
# 功能 3: 卸载 Claude Code
# 复用 clear.sh 的全部逻辑，增加二次确认
# =============================================================================

do_uninstall() {
    echo -e "\n${BLUE}=== 卸载 Claude Code ===${NC}"
    echo -e "检测到系统: ${CYAN}${OS_TYPE}${NC}"

    # ---- 二次确认 ----
    echo -e "\n${YELLOW}[警告] 此操作将卸载 Claude Code 并清除相关配置.${NC}"
    read -p "确认继续? (y/n): " CONFIRM < /dev/tty
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[Cancelled] 操作已取消.${NC}"
        return
    fi

    # ---- 检测安装方式 ----
    echo -e "\n${BLUE}[Step 1/5] 检测 Claude Code 安装方式...${NC}"

    local INSTALL_METHOD=""

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
        local CLAUDE_PATH
        CLAUDE_PATH=$(which claude 2>/dev/null || true)
        echo -e "检测到安装方式: ${CYAN}官方安装器 / 手动安装${NC}"
        echo -e "可执行文件路径: ${YELLOW}${CLAUDE_PATH}${NC}"
    else
        echo -e "${YELLOW}[Notice] 未检测到 Claude Code 安装.${NC}"
    fi

    # ---- 扫描待清理项 ----
    echo -e "\n${BLUE}[Step 2/5] 扫描待清理项...${NC}"

    local ITEMS_TO_CLEAN=()

    # ~/.claude/ 目录
    if [ -d "$HOME/.claude" ]; then
        ITEMS_TO_CLEAN+=("$HOME/.claude")
        echo -e "  ${YELLOW}~/.claude/${NC} (配置、缓存、插件等)"
    fi

    # ~/.claude.json
    if [ -f "$HOME/.claude.json" ]; then
        ITEMS_TO_CLEAN+=("$HOME/.claude.json")
        echo -e "  ${YELLOW}~/.claude.json${NC}"
    fi

    # ~/.claude.json.backup*
    for bf in "$HOME"/.claude.json.backup*; do
        [ -e "$bf" ] || continue
        ITEMS_TO_CLEAN+=("$bf")
        echo -e "  ${YELLOW}~/${bf##*/}${NC}"
    done

    # ~/.anthropic-api-key
    if [ -f "$HOME/.anthropic-api-key" ]; then
        ITEMS_TO_CLEAN+=("$HOME/.anthropic-api-key")
        echo -e "  ${YELLOW}~/.anthropic-api-key${NC}"
    fi

    # macOS 缓存目录
    if [ "$OS_TYPE" = "macos" ] && [ -d "$HOME/Library/Caches/claude-cli-nodejs" ]; then
        ITEMS_TO_CLEAN+=("$HOME/Library/Caches/claude-cli-nodejs")
        echo -e "  ${YELLOW}~/Library/Caches/claude-cli-nodejs/${NC}"
    fi

    # 如果什么都没找到且未安装
    if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ] && [ -z "$INSTALL_METHOD" ]; then
        echo -e "\n${GREEN}[Success] 系统中未发现 Claude Code 的任何安装或配置文件.${NC}"
        echo -e "无需清理，退出."
        return
    fi

    if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}(未发现配置文件)${NC}"
    fi

    # ---- 用户选择操作 ----
    echo -e "\n${BLUE}[Step 3/5] 请确认操作...${NC}"

    local USER_CHOICE=""

    if [ -n "$INSTALL_METHOD" ]; then
        echo -e "${CYAN}请选择操作:${NC}"
        echo -e "  ${GREEN}1)${NC} 完整卸载 + 清除所有配置"
        echo -e "  ${YELLOW}2)${NC} 仅清除配置文件（保留程序）"
        echo -e "  ${RED}0)${NC} 取消"
        echo ""
        read -p "请输入选项 (0/1/2): " USER_CHOICE < /dev/tty

        case "$USER_CHOICE" in
            1) echo -e "${BLUE}已选择: 完整卸载 + 清除配置${NC}" ;;
            2) echo -e "${BLUE}已选择: 仅清除配置文件${NC}" ;;
            0|"")
                echo -e "${RED}[Cancelled] 操作已取消.${NC}"
                return
                ;;
            *)
                echo -e "${RED}[Error] 无效的选项: $USER_CHOICE${NC}"
                return
                ;;
        esac
    else
        echo -e "将清除以上列出的 ${CYAN}${#ITEMS_TO_CLEAN[@]}${NC} 个配置项."
        read -p "确认清除? (y/n): " CONFIRM2 < /dev/tty
        if [[ ! "$CONFIRM2" =~ ^[Yy]$ ]]; then
            echo -e "${RED}[Cancelled] 操作已取消.${NC}"
            return
        fi
        USER_CHOICE="2"
    fi

    # ---- 卸载程序（条件执行）----
    local UNINSTALL_SUCCESS=true

    if [ "$USER_CHOICE" = "1" ]; then
        echo -e "\n${BLUE}[Step 4/5] 卸载 Claude Code 程序...${NC}"

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
                local CLAUDE_BIN
                CLAUDE_BIN=$(which claude 2>/dev/null || true)
                local REMOVED_BIN=false

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
        echo -e "\n${BLUE}[Step 4/5] 跳过卸载（保留程序）.${NC}"
    fi

    # ---- 清除配置文件 ----
    echo -e "\n${BLUE}[Step 5/5] 清除配置文件...${NC}"

    local DELETED_COUNT=0
    local FAILED_COUNT=0

    for item in "${ITEMS_TO_CLEAN[@]}"; do
        local DISPLAY_NAME="${item/#$HOME/~}"
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

    # ---- 验证结果 ----
    echo -e "\n${BLUE}验证清理结果...${NC}"

    local ALL_CLEAN=true

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
    else
        echo -e "\n${YELLOW}[Warning] 部分项目未能清理，请检查上方输出.${NC}"
    fi
}

# =============================================================================
# 入口菜单
# =============================================================================

echo -e "${BLUE}=== Claude Code 设置工具 ===${NC}"
echo -e "检测到系统: ${CYAN}${OS_TYPE}${NC}\n"

echo -e "${CYAN}请选择操作:${NC}"
echo -e "  ${GREEN}1)${NC} 安装 Claude Code"
echo -e "  ${GREEN}2)${NC} 设置 API"
echo -e "  ${RED}3)${NC} 卸载 Claude Code"
echo -e "  ${RED}0)${NC} 退出"
echo ""
read -p "请输入选项 (0/1/2/3): " MENU_CHOICE < /dev/tty

case "$MENU_CHOICE" in
    1) do_install ;;
    2) do_set_api ;;
    3) do_uninstall ;;
    0|"")
        echo -e "${YELLOW}已退出.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] 无效的选项: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
