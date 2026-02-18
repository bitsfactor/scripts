#!/bin/bash

# =============================================================================
# Claude Code Setup Tool
# All-in-one menu: install Claude Code, configure API, or uninstall.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash claude.sh
#   curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude.sh | bash
# =============================================================================

set -e

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
clean_settings_json() {
    local file="$HOME/.claude/settings.json"
    if [ ! -f "$file" ]; then
        return
    fi

    local cleaned=false

    for var in "${CLEAN_VARS[@]}"; do
        if grep -q "\"${var}\"" "$file" 2>/dev/null; then
            grep -v "\"${var}\"" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
            cleaned=true
        fi
    done

    if [ "$cleaned" = true ]; then
        # Fix trailing comma issues in JSON
        perl -0777 -i -pe 's/,(\s*[}\]])/\1/g' "$file" 2>/dev/null || true

        # Remove empty env object if present
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

        echo -e "  ${GREEN}✓${NC} Cleaned ~/.claude/settings.json env entries"
    fi
}

# clean_all_shell_configs: clean all known shell config files
clean_all_shell_configs() {
    local SHELL_CONFIGS=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
    for config in "${SHELL_CONFIGS[@]}"; do
        clean_shell_config "$config"
    done
}

# =============================================================================
# 1) Install Claude Code
# =============================================================================

do_install() {
    echo -e "\n${BLUE}=== Install Claude Code ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}\n"

    echo -e "${BLUE}Installing via official installer...${NC}\n"

    local tmp_installer
    tmp_installer=$(mktemp)
    if ! curl -fsSL https://claude.ai/install.sh -o "$tmp_installer"; then
        echo -e "${RED}[Error] Failed to download installer.${NC}"
        rm -f "$tmp_installer"
        return 1
    fi
    bash "$tmp_installer" || { rm -f "$tmp_installer"; return 1; }
    rm -f "$tmp_installer"

    echo -e "\n${GREEN}[Success] Claude Code installed!${NC}"
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

    # ---- Write new config to ~/.zshrc ----
    echo -e "\n${BLUE}[Step 3/4] Writing new config to ~/.zshrc...${NC}"

    touch "$HOME/.zshrc"

    cat >> "$HOME/.zshrc" << EOF

# >>> Claude Code API config (managed by claude.sh) >>>
export ANTHROPIC_BASE_URL='${INPUT_URL}'
export ANTHROPIC_AUTH_TOKEN='${INPUT_TOKEN}'
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
# <<< Claude Code API config <<<
EOF

    echo -e "  ${GREEN}✓${NC} Written to ~/.zshrc"

    # ---- Summary ----
    echo -e "\n${BLUE}[Step 4/4] Configuration summary...${NC}"

    echo -e "\n${CYAN}========================================${NC}"
    echo -e "  Written to ~/.zshrc:"
    echo -e "  ${GREEN}ANTHROPIC_BASE_URL${NC}  = ${YELLOW}${INPUT_URL}${NC}"
    echo -e "  ${GREEN}ANTHROPIC_AUTH_TOKEN${NC} = ${YELLOW}******${NC}"
    echo -e "  ${GREEN}CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC${NC} = ${YELLOW}1${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "\n${GREEN}[Success] Claude Code API configured!${NC}"
    echo -e "${YELLOW}[Reminder] To apply the changes:${NC}"
    echo -e "  1. Reopen your terminal"
    echo -e "  2. Or run: ${CYAN}source ~/.zshrc${NC}"
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

    local INSTALL_METHOD=""

    if command -v npm &> /dev/null && npm list -g @anthropic-ai/claude-code 2>/dev/null | grep -q "claude-code"; then
        INSTALL_METHOD="npm"
        echo -e "Detected: ${CYAN}NPM global install${NC}"
    elif [ "$OS_TYPE" = "macos" ] && command -v brew &> /dev/null && brew list --cask claude-code 2>/dev/null | grep -q "."; then
        INSTALL_METHOD="homebrew"
        echo -e "Detected: ${CYAN}Homebrew Cask${NC}"
    elif command -v claude &> /dev/null; then
        INSTALL_METHOD="other"
        local CLAUDE_PATH
        CLAUDE_PATH=$(which claude 2>/dev/null || true)
        echo -e "Detected: ${CYAN}Official installer / manual${NC}"
        echo -e "Binary path: ${YELLOW}${CLAUDE_PATH}${NC}"
    else
        echo -e "${YELLOW}[Notice] Claude Code installation not detected.${NC}"
    fi

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
                local CLAUDE_BIN
                CLAUDE_BIN=$(which claude 2>/dev/null || true)
                local REMOVED_BIN=false

                if [ -n "$CLAUDE_BIN" ]; then
                    if rm "$CLAUDE_BIN" 2>/dev/null || sudo rm "$CLAUDE_BIN" 2>/dev/null; then
                        echo -e "${GREEN}[Success] Removed ${CLAUDE_BIN}${NC}"
                        REMOVED_BIN=true
                    else
                        echo -e "${RED}[Error] Cannot remove ${CLAUDE_BIN}${NC}"
                    fi
                fi

                if [ -f "$HOME/.local/bin/claude" ]; then
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

echo -e "${BLUE}=== Claude Code Setup ===${NC}"
echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
echo -e "  ${GREEN}1)${NC} Install Claude Code"
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
