#!/bin/bash

# =============================================================================
# Claude Code Setup Tool
# All-in-one menu: install / update, configure API, or uninstall Claude Code.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash claude.sh
#   curl -s https://cdn.jsdelivr.net/gh/bitsfactor/scripts@main/claude.sh | bash
# =============================================================================

set -e

VERSION="1.0.0"

# Color definitions
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

# ---- OS detection ----

OS_TYPE=""
case "$OSTYPE" in
    darwin*)  OS_TYPE="macos" ;;
    linux*)   OS_TYPE="linux" ;;
    *)
        echo -e "${RED}[Error] Unsupported OS: $OSTYPE${NC}"
        echo -e "${YELLOW}This script only supports macOS and Linux.${NC}"
        exit 1
        ;;
esac

# ---- Detect user's login shell RC file ----

USER_SHELL="$(basename "${SHELL:-/bin/bash}")"
case "$USER_SHELL" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    *)    SHELL_RC="$HOME/.bashrc" ;;
esac

# ---- Shared variables for API config cleanup ----

CLEAN_VARS=("ANTHROPIC_BASE_URL" "ANTHROPIC_AUTH_TOKEN" "ANTHROPIC_API_KEY" "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" "API_TIMEOUT_MS")
BLOCK_START="# >>> Claude Code API"
BLOCK_END="# <<< Claude Code API"

# ---- Shared functions ----

# sed_inplace: cross-platform sed -i wrapper
# Args: $1 = sed expression, $2 = file path
sed_inplace() {
    if [ "$OS_TYPE" = "macos" ]; then
        sed -i '' "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

# clean_shell_config: remove Claude Code API entries from a shell config file
# Args: $1 = file path
clean_shell_config() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi

    local display_name="${file/#$HOME/~}"
    local cleaned=false

    # 1) Remove marker block
    if grep -q "$BLOCK_START" "$file" 2>/dev/null; then
        sed_inplace "/$BLOCK_START/,/$BLOCK_END/d" "$file"
        cleaned=true
    fi

    # 2) Remove stray export lines outside marker block
    for var in "${CLEAN_VARS[@]}"; do
        if grep -q "^export ${var}=" "$file" 2>/dev/null; then
            sed_inplace "/^export ${var}=/d" "$file"
            cleaned=true
        fi
    done

    if [ "$cleaned" = true ]; then
        echo -e "  ${GREEN}✓${NC} Cleaned ${display_name}"
    fi
}

# clean_settings_json: remove Claude Code API keys from ~/.claude/settings.json
# 纯 shell 实现：sed 删除目标 key 行，awk 修复 JSON 格式（尾逗号、空 env 块）
clean_settings_json() {
    local file="$HOME/.claude/settings.json"
    if [ ! -f "$file" ]; then
        return
    fi

    # 检查文件中是否存在目标 key
    local has_keys=false
    for var in "${CLEAN_VARS[@]}"; do
        if grep -q "\"${var}\"" "$file" 2>/dev/null; then
            has_keys=true
            break
        fi
    done

    if [ "$has_keys" = false ]; then
        return
    fi

    # 删除包含目标 key 的行
    # 注意：匹配整个文件而非仅 env 块，因为 CLEAN_VARS 中的 key 名（如 ANTHROPIC_BASE_URL）
    # 在 settings.json 中不会出现在 env 以外的位置，实际不会误删
    for var in "${CLEAN_VARS[@]}"; do
        sed_inplace "/\"${var}\"/d" "$file"
    done

    # 用 awk 修复 JSON 格式：移除空 env 块、修复尾逗号
    local tmp
    tmp=$(mktemp)

    awk '
    { lines[NR] = $0 }
    END {
        n = NR

        # 第一轮：移除空 "env": { } 块
        for (i = 1; i <= n; i++) {
            if (lines[i] ~ /"env"[[:space:]]*:[[:space:]]*\{[[:space:]]*$/) {
                j = i + 1
                while (j <= n && lines[j] ~ /^[[:space:]]*$/) j++
                if (j <= n && lines[j] ~ /^[[:space:]]*\},?[[:space:]]*$/) {
                    for (k = i; k <= j; k++) lines[k] = ""
                }
            }
        }

        # 第二轮：修复尾逗号（逗号后紧跟 } 或 ]）
        for (i = 1; i <= n; i++) {
            if (lines[i] == "") continue
            if (lines[i] ~ /,$/) {
                j = i + 1
                while (j <= n && (lines[j] == "" || lines[j] ~ /^[[:space:]]*$/)) j++
                if (j <= n && lines[j] ~ /^[[:space:]]*[}\]]/) {
                    sub(/,$/, "", lines[i])
                }
            }
        }

        # 输出非空行
        for (i = 1; i <= n; i++) {
            if (lines[i] != "") print lines[i]
        }
    }
    ' "$file" > "$tmp"

    # 检查 awk 输出非空，避免用空文件覆盖原文件
    if [ ! -s "$tmp" ]; then
        echo -e "  ${YELLOW}[Warning] Failed to process ~/.claude/settings.json${NC}"
        rm -f "$tmp"
        return
    fi

    if mv "$tmp" "$file"; then
        echo -e "  ${GREEN}✓${NC} Cleaned ~/.claude/settings.json env entries"
    else
        echo -e "  ${YELLOW}[Warning] Failed to update ~/.claude/settings.json${NC}"
        rm -f "$tmp"
    fi
}

# clean_all_shell_configs: clean all known shell config files
clean_all_shell_configs() {
    local SHELL_CONFIGS=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
    for config in "${SHELL_CONFIGS[@]}"; do
        clean_shell_config "$config"
    done
}

# run_official_installer: 下载并执行官方安装脚本
# 用于 install 和 update (other 方式) 的公共逻辑
run_official_installer() {
    local tmp_installer
    tmp_installer=$(mktemp)
    if ! curl -fsSL https://claude.ai/install.sh -o "$tmp_installer"; then
        echo -e "${RED}[Error] Failed to download installer.${NC}"
        rm -f "$tmp_installer"
        return 1
    fi
    bash "$tmp_installer" || { rm -f "$tmp_installer"; return 1; }
    rm -f "$tmp_installer"
}

# detect_install_method: 检测 Claude Code 的安装方式
# 设置全局变量 INSTALL_METHOD: "npm" / "homebrew" / "other" / ""
# 同时设置 CLAUDE_PATH（仅 other 方式时有值）
detect_install_method() {
    INSTALL_METHOD=""
    CLAUDE_PATH=""

    if command -v npm &> /dev/null && npm list -g @anthropic-ai/claude-code 2>/dev/null | grep -q "claude-code"; then
        INSTALL_METHOD="npm"
        echo -e "Detected: ${CYAN}NPM global install${NC}"
    elif [ "$OS_TYPE" = "macos" ] && command -v brew &> /dev/null && brew list --cask claude-code 2>/dev/null | grep -q "."; then
        INSTALL_METHOD="homebrew"
        echo -e "Detected: ${CYAN}Homebrew Cask${NC}"
    elif command -v claude &> /dev/null; then
        INSTALL_METHOD="other"
        CLAUDE_PATH=$(which claude 2>/dev/null || true)
        echo -e "Detected: ${CYAN}Official installer / manual${NC}"
        echo -e "Binary path: ${YELLOW}${CLAUDE_PATH}${NC}"
    else
        echo -e "${YELLOW}[Notice] Claude Code installation not detected.${NC}"
    fi
}

# =============================================================================
# 1) Install / Update Claude Code
# =============================================================================

do_install() {
    echo -e "\n${BLUE}=== Install / Update Claude Code ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    # ---- Detect install method ----
    echo -e "\n${BLUE}[Step 1/2] Detecting install method...${NC}"

    detect_install_method

    # ---- Install or update ----
    echo -e "\n${BLUE}[Step 2/2] Installing / updating Claude Code...${NC}"

    if [ -z "$INSTALL_METHOD" ]; then
        echo -e "No existing installation found. Installing via official installer...\n"
        if ! run_official_installer; then
            return 1
        fi
    else
        case "$INSTALL_METHOD" in
            npm)
                echo -e "Updating via NPM..."
                if npm update -g @anthropic-ai/claude-code; then
                    echo -e "${GREEN}[Success] NPM update complete.${NC}"
                else
                    echo -e "${YELLOW}[Warning] NPM update failed, trying sudo...${NC}"
                    if sudo npm update -g @anthropic-ai/claude-code; then
                        echo -e "${GREEN}[Success] NPM update complete (sudo).${NC}"
                    else
                        echo -e "${RED}[Error] NPM update failed.${NC}"
                        return 1
                    fi
                fi
                ;;
            homebrew)
                echo -e "Updating via Homebrew..."
                if brew upgrade --cask claude-code; then
                    echo -e "${GREEN}[Success] Homebrew upgrade complete.${NC}"
                else
                    echo -e "${RED}[Error] Homebrew upgrade failed.${NC}"
                    return 1
                fi
                ;;
            other)
                echo -e "Updating via official installer...\n"
                if ! run_official_installer; then
                    return 1
                fi
                ;;
        esac
    fi

    # ---- Show version ----
    echo -e "\n${CYAN}Current version:${NC}"
    claude --version 2>/dev/null || echo -e "${YELLOW}[Warning] Could not retrieve version.${NC}"

    echo -e "\n${GREEN}[Success] Claude Code is ready!${NC}"
}

# =============================================================================
# 2) Set API — configure ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN
# =============================================================================

do_set_api() {
    echo -e "\n${BLUE}=== Configure Claude Code API ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    # ---- Prompt for input ----
    echo -e "\n${BLUE}[Step 1/4] Enter API configuration...${NC}"

    echo -e "${CYAN}Enter ANTHROPIC_BASE_URL (API endpoint):${NC}"
    read -r INPUT_URL < /dev/tty

    if [ -z "$INPUT_URL" ]; then
        echo -e "${RED}[Error] API endpoint cannot be empty.${NC}"
        return 1
    fi

    echo -e "${CYAN}Enter ANTHROPIC_AUTH_TOKEN (API key):${NC}"
    read -r INPUT_TOKEN < /dev/tty

    if [ -z "$INPUT_TOKEN" ]; then
        echo -e "${RED}[Error] API key cannot be empty.${NC}"
        return 1
    fi

    echo -e "${GREEN}Input received.${NC}"

    # ---- Clean old config ----
    echo -e "\n${BLUE}[Step 2/4] Cleaning old configuration...${NC}"

    clean_all_shell_configs
    clean_settings_json

    echo -e "  ${GREEN}Old config cleanup done.${NC}"

    # ---- Write new config to shell RC file ----
    local SHELL_RC_DISPLAY="${SHELL_RC/#$HOME/~}"
    echo -e "\n${BLUE}[Step 3/4] Writing new config to ${SHELL_RC_DISPLAY}...${NC}"

    touch "$SHELL_RC"

    cat >> "$SHELL_RC" << EOF

# >>> Claude Code API config (managed by claude.sh) >>>
export ANTHROPIC_BASE_URL='${INPUT_URL}'
export ANTHROPIC_AUTH_TOKEN='${INPUT_TOKEN}'
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
# <<< Claude Code API config <<<
EOF

    echo -e "  ${GREEN}✓${NC} Written to ${SHELL_RC_DISPLAY}"

    # ---- Summary ----
    echo -e "\n${BLUE}[Step 4/4] Configuration summary...${NC}"

    echo -e "\n${CYAN}========================================${NC}"
    echo -e "  Written to ${SHELL_RC_DISPLAY}:"
    echo -e "  ${GREEN}ANTHROPIC_BASE_URL${NC}  = ${YELLOW}${INPUT_URL}${NC}"
    echo -e "  ${GREEN}ANTHROPIC_AUTH_TOKEN${NC} = ${YELLOW}******${NC}"
    echo -e "  ${GREEN}CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC${NC} = ${YELLOW}1${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "\n${GREEN}[Success] Claude Code API configured!${NC}"
    echo -e "${YELLOW}[Reminder] To apply the changes:${NC}"
    echo -e "  1. Reopen your terminal"
    echo -e "  2. Or run: ${CYAN}source ${SHELL_RC_DISPLAY}${NC}"
}

# =============================================================================
# 3) Uninstall Claude Code — detect install method, remove binary and configs
# =============================================================================

do_uninstall() {
    echo -e "\n${BLUE}=== Uninstall Claude Code ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    # ---- Confirmation ----
    echo -e "\n${YELLOW}[Warning] This will uninstall Claude Code and remove related config.${NC}"
    read -p "Continue? (y/n): " CONFIRM < /dev/tty
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[Cancelled] Operation cancelled.${NC}"
        return
    fi

    # ---- Detect install method ----
    echo -e "\n${BLUE}[Step 1/6] Detecting install method...${NC}"

    detect_install_method

    # ---- Scan config items ----
    echo -e "\n${BLUE}[Step 2/6] Scanning config files...${NC}"

    local ITEMS_TO_CLEAN=()

    if [ -d "$HOME/.claude" ]; then
        ITEMS_TO_CLEAN+=("$HOME/.claude")
        echo -e "  ${YELLOW}~/.claude/${NC} (config, cache, plugins)"
    fi

    if [ -f "$HOME/.claude.json" ]; then
        ITEMS_TO_CLEAN+=("$HOME/.claude.json")
        echo -e "  ${YELLOW}~/.claude.json${NC}"
    fi

    for bf in "$HOME"/.claude.json.backup*; do
        [ -e "$bf" ] || continue
        ITEMS_TO_CLEAN+=("$bf")
        echo -e "  ${YELLOW}~/${bf##*/}${NC}"
    done

    if [ -f "$HOME/.anthropic-api-key" ]; then
        ITEMS_TO_CLEAN+=("$HOME/.anthropic-api-key")
        echo -e "  ${YELLOW}~/.anthropic-api-key${NC}"
    fi

    if [ "$OS_TYPE" = "macos" ] && [ -d "$HOME/Library/Caches/claude-cli-nodejs" ]; then
        ITEMS_TO_CLEAN+=("$HOME/Library/Caches/claude-cli-nodejs")
        echo -e "  ${YELLOW}~/Library/Caches/claude-cli-nodejs/${NC}"
    fi

    # Check for shell config entries
    local HAS_SHELL_CONFIG=false
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
        if [ -f "$rc" ] && grep -q "$BLOCK_START" "$rc" 2>/dev/null; then
            HAS_SHELL_CONFIG=true
            echo -e "  ${YELLOW}${rc/#$HOME/~}${NC} (API env vars)"
        fi
    done

    if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ] && [ -z "$INSTALL_METHOD" ] && [ "$HAS_SHELL_CONFIG" = false ]; then
        echo -e "\n${GREEN}[Success] No Claude Code installation or config found.${NC}"
        echo -e "Nothing to clean."
        return
    fi

    if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ] && [ "$HAS_SHELL_CONFIG" = false ]; then
        echo -e "  ${YELLOW}(No config files found)${NC}"
    fi

    # ---- User choice ----
    echo -e "\n${BLUE}[Step 3/6] Choose operation...${NC}"

    local USER_CHOICE=""

    if [ -n "$INSTALL_METHOD" ]; then
        echo -e "${CYAN}Select an option:${NC}"
        echo -e "  ${GREEN}1)${NC} Full uninstall + remove all config"
        echo -e "  ${YELLOW}2)${NC} Remove config only (keep program)"
        echo -e "  ${RED}0)${NC} Cancel"
        echo ""
        read -p "Enter option (0/1/2): " USER_CHOICE < /dev/tty

        case "$USER_CHOICE" in
            1) echo -e "${BLUE}Selected: Full uninstall + remove config${NC}" ;;
            2) echo -e "${BLUE}Selected: Remove config only${NC}" ;;
            0|"")
                echo -e "${RED}[Cancelled] Operation cancelled.${NC}"
                return
                ;;
            *)
                echo -e "${RED}[Error] Invalid option: $USER_CHOICE${NC}"
                return
                ;;
        esac
    else
        echo -e "Will clean the items listed above."
        read -p "Confirm? (y/n): " CONFIRM2 < /dev/tty
        if [[ ! "$CONFIRM2" =~ ^[Yy]$ ]]; then
            echo -e "${RED}[Cancelled] Operation cancelled.${NC}"
            return
        fi
        USER_CHOICE="2"
    fi

    # ---- Uninstall program (conditional) ----
    local UNINSTALL_SUCCESS=true

    if [ "$USER_CHOICE" = "1" ]; then
        echo -e "\n${BLUE}[Step 4/6] Uninstalling Claude Code...${NC}"

        case "$INSTALL_METHOD" in
            npm)
                echo -e "Uninstalling via NPM..."
                if npm uninstall -g @anthropic-ai/claude-code 2>/dev/null; then
                    echo -e "${GREEN}[Success] NPM uninstall complete.${NC}"
                else
                    echo -e "${YELLOW}[Warning] NPM uninstall failed, trying sudo...${NC}"
                    if sudo npm uninstall -g @anthropic-ai/claude-code 2>/dev/null; then
                        echo -e "${GREEN}[Success] NPM uninstall complete (sudo).${NC}"
                    else
                        echo -e "${RED}[Error] NPM uninstall failed.${NC}"
                        UNINSTALL_SUCCESS=false
                    fi
                fi
                ;;
            homebrew)
                echo -e "Uninstalling via Homebrew..."
                if brew uninstall --cask claude-code 2>/dev/null; then
                    echo -e "${GREEN}[Success] Homebrew uninstall complete.${NC}"
                else
                    echo -e "${RED}[Error] Homebrew uninstall failed.${NC}"
                    UNINSTALL_SUCCESS=false
                fi
                ;;
            other)
                echo -e "Removing binary..."
                local REMOVED_BIN=false

                if [ -n "$CLAUDE_PATH" ]; then
                    if rm "$CLAUDE_PATH" 2>/dev/null || sudo rm "$CLAUDE_PATH" 2>/dev/null; then
                        echo -e "${GREEN}[Success] Removed ${CLAUDE_PATH}${NC}"
                        REMOVED_BIN=true
                    else
                        echo -e "${RED}[Error] Cannot remove ${CLAUDE_PATH}${NC}"
                    fi
                fi

                # 避免与 CLAUDE_PATH 重复删除同一文件
                if [ -f "$HOME/.local/bin/claude" ] && [ "$CLAUDE_PATH" != "$HOME/.local/bin/claude" ]; then
                    if rm "$HOME/.local/bin/claude" 2>/dev/null; then
                        echo -e "${GREEN}[Success] Removed ~/.local/bin/claude${NC}"
                        REMOVED_BIN=true
                    else
                        echo -e "${RED}[Error] Cannot remove ~/.local/bin/claude${NC}"
                    fi
                fi

                if [ "$REMOVED_BIN" = false ]; then
                    echo -e "${RED}[Error] Failed to remove any binary.${NC}"
                    UNINSTALL_SUCCESS=false
                fi
                ;;
        esac
    else
        echo -e "\n${BLUE}[Step 4/6] Skipped uninstall (keeping program).${NC}"
    fi

    # ---- Clean shell config entries ----
    echo -e "\n${BLUE}[Step 5/6] Cleaning shell config entries...${NC}"

    clean_all_shell_configs

    echo -e "  ${GREEN}Shell config cleanup done.${NC}"

    # ---- Remove config files ----
    echo -e "\n${BLUE}[Step 6/6] Removing config files...${NC}"

    local DELETED_COUNT=0
    local FAILED_COUNT=0

    for item in "${ITEMS_TO_CLEAN[@]}"; do
        local DISPLAY_NAME="${item/#$HOME/~}"
        if rm -rf "$item" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Removed ${DISPLAY_NAME}"
            DELETED_COUNT=$((DELETED_COUNT + 1))
        else
            if sudo rm -rf "$item" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Removed ${DISPLAY_NAME} (sudo)"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            else
                echo -e "  ${RED}✗${NC} Cannot remove ${DISPLAY_NAME}"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        fi
    done

    if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}(No config files to clean)${NC}"
    fi

    # ---- Verify results ----
    echo -e "\n${BLUE}Verifying cleanup...${NC}"

    local ALL_CLEAN=true

    if [ "$USER_CHOICE" = "1" ]; then
        if command -v claude &> /dev/null; then
            echo -e "  ${RED}✗${NC} claude command still exists: $(which claude)"
            ALL_CLEAN=false
        else
            echo -e "  ${GREEN}✓${NC} claude command removed"
        fi
    fi

    if [ -d "$HOME/.claude" ]; then
        echo -e "  ${RED}✗${NC} ~/.claude/ still exists"
        ALL_CLEAN=false
    else
        echo -e "  ${GREEN}✓${NC} ~/.claude/ cleaned"
    fi

    if [ -f "$HOME/.claude.json" ]; then
        echo -e "  ${RED}✗${NC} ~/.claude.json still exists"
        ALL_CLEAN=false
    else
        echo -e "  ${GREEN}✓${NC} ~/.claude.json cleaned"
    fi

    # Summary
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "  Removed: ${GREEN}${DELETED_COUNT}${NC} items"
    if [ $FAILED_COUNT -gt 0 ]; then
        echo -e "  Failed:  ${RED}${FAILED_COUNT}${NC} items"
    fi
    if [ "$USER_CHOICE" = "1" ]; then
        if [ "$UNINSTALL_SUCCESS" = true ]; then
            echo -e "  Program: ${GREEN}uninstalled${NC}"
        else
            echo -e "  Program: ${RED}uninstall failed${NC}"
        fi
    fi
    echo -e "${CYAN}========================================${NC}"

    if [ "$ALL_CLEAN" = true ] && [ $FAILED_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}[Success] Claude Code cleanup complete!${NC}"
    else
        echo -e "\n${YELLOW}[Warning] Some items could not be cleaned. Check output above.${NC}"
    fi
}

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}=== Claude Code Setup v${VERSION} ===${NC}"
echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
echo -e "  ${GREEN}1)${NC} Install / Update Claude Code"
echo -e "  ${GREEN}2)${NC} Set API"
echo -e "  ${RED}3)${NC} Uninstall Claude Code"
echo -e "  ${RED}0)${NC} Exit"
echo ""
read -p "Enter option (0/1/2/3): " MENU_CHOICE < /dev/tty

case "$MENU_CHOICE" in
    1) do_install ;;
    2) do_set_api ;;
    3) do_uninstall ;;
    0|"")
        echo -e "${YELLOW}Exited.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] Invalid option: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
