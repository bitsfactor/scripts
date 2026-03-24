#!/bin/bash

# =============================================================================
# Codex Setup Tool
# Install Codex CLI or configure third-party API access.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash codex.sh
# =============================================================================

set -e

# Load version: BFS_VER env var (remote) > local version.sh (development)
_SCRIPT_DIR=""
[ -n "${BASH_SOURCE[0]}" ] && _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd 2>/dev/null)"
[ -n "$_SCRIPT_DIR" ] && [ -f "$_SCRIPT_DIR/version.sh" ] && . "$_SCRIPT_DIR/version.sh"
[ -n "$BFS_VER" ] && VERSION="$BFS_VER"

: "${CDN_BASE:=https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v${VERSION}}"

# Color definitions
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

# ---- OS detection ----

OS_TYPE=""
case "$(uname -s)" in
    Darwin*)  OS_TYPE="macos" ;;
    Linux*)   OS_TYPE="linux" ;;
    *)
        echo -e "${RED}[Error] Unsupported OS: $(uname -s)${NC}"
        echo -e "${YELLOW}This script only supports macOS and Linux.${NC}"
        exit 1
        ;;
esac

# ---- Detect user's login shell RC file ----

USER_SHELL="$(basename "${SHELL:-/bin/bash}")"
case "$USER_SHELL" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    *)
        if [ "$OS_TYPE" = "macos" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
        ;;
esac

# ---- Shared variables for Codex API config cleanup ----

DEFAULT_BASE_URL="https://api.develop.cc/v1"
CODEX_CONFIG_DIR="$HOME/.codex"
CODEX_CONFIG_FILE="$CODEX_CONFIG_DIR/config.toml"
CLEAN_VARS=("OPENAI_API_KEY" "OPENAI_BASE_URL")
BLOCK_START="# >>> BitsFactor codex API"
BLOCK_END="# <<< BitsFactor codex API"

# ---- Shared functions ----

# tty_read: read one line from /dev/tty
# Args: $1 = variable name to store result
#       $2 = (optional) prompt string (written directly to /dev/tty)
tty_read() {
    [ -n "$2" ] && printf '%s' "$2" > /dev/tty
    IFS= read -r "$1" < /dev/tty || true
}

# sed_inplace: cross-platform sed -i wrapper
# Args: $1 = sed expression, $2 = file path
sed_inplace() {
    if [ "$OS_TYPE" = "macos" ]; then
        sed -i '' "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

# clean_shell_config: remove Codex API entries from a shell config file
# Args: $1 = file path
clean_shell_config() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi

    local cleaned=false

    if grep -qF "$BLOCK_START" "$file" 2>/dev/null; then
        sed_inplace "/$BLOCK_START/,/$BLOCK_END/d" "$file"
        cleaned=true
    fi

    for var in "${CLEAN_VARS[@]}"; do
        if grep -q "^export ${var}=" "$file" 2>/dev/null; then
            sed_inplace "/^export ${var}=/d" "$file"
            cleaned=true
        fi
    done

    if [ "$cleaned" = true ]; then
        echo -e "  ${GREEN}✓${NC} Cleaned ${file/#$HOME/~}"
    fi
}

clean_all_shell_configs() {
    clean_shell_config "$HOME/.zshrc"
    clean_shell_config "$HOME/.bashrc"
    clean_shell_config "$HOME/.bash_profile"
}

print_source_reminder() {
    local rc_display="${SHELL_RC/#$HOME/~}"
    echo -e "\n${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Apply changes in your current terminal:${NC}"
    echo -e "    ${CYAN}source ${rc_display}${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
}

# =============================================================================
# 1) Install Codex
# =============================================================================

do_install_codex() {
    echo -e "\n${BLUE}=== Install Codex ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    echo -e "\n${BLUE}[Step 1/2] Checking npm...${NC}"
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}[Error] npm not found.${NC}"
        echo -e "${YELLOW}Please install Node.js first (run env.sh and select 'Install Node.js & npm').${NC}"
        return 1
    fi
    echo -e "  ${GREEN}✓${NC} npm found: $(npm --version)"

    echo -e "\n${BLUE}[Step 2/2] Installing Codex CLI...${NC}"
    npm i -g @openai/codex || return 1

    if command -v codex &> /dev/null; then
        echo -e "\n${CYAN}Current version:${NC}"
        codex --version 2>/dev/null || echo -e "${YELLOW}[Warning] Could not retrieve version.${NC}"
        echo -e "\n${GREEN}[Success] Codex is ready!${NC}"
    else
        echo -e "${RED}[Error] Codex installation may have failed.${NC}"
        return 1
    fi
}

# =============================================================================
# 2) Set API — configure OPENAI_API_KEY / OPENAI_BASE_URL and ~/.codex/config.toml
# =============================================================================

do_set_api() {
    echo -e "\n${BLUE}=== Configure Codex API ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    echo -e "\n${BLUE}[Step 1/4] Enter API configuration...${NC}"

    local INPUT_URL=""
    local INPUT_TOKEN=""

    tty_read INPUT_URL "Enter OPENAI_BASE_URL [${DEFAULT_BASE_URL}]: "
    : "${INPUT_URL:=$DEFAULT_BASE_URL}"

    if [[ "$INPUT_URL" != [hH][tT][tT][pP]://* ]] && [[ "$INPUT_URL" != [hH][tT][tT][pP][sS]://* ]]; then
        INPUT_URL="https://${INPUT_URL}"
        echo -e "${YELLOW}[Auto] Added https:// prefix → ${INPUT_URL}${NC}"
    fi

    tty_read INPUT_TOKEN "Enter OPENAI_API_KEY: "
    if [ -z "$INPUT_TOKEN" ]; then
        echo -e "${RED}[Error] API key cannot be empty.${NC}"
        return 1
    fi

    echo -e "${GREEN}Input received.${NC}"

    echo -e "\n${BLUE}[Step 2/4] Cleaning old configuration...${NC}"
    clean_all_shell_configs
    echo -e "  ${GREEN}Old config cleanup done.${NC}"

    echo -e "\n${BLUE}[Step 3/4] Writing shell environment...${NC}"
    local SHELL_RC_DISPLAY="${SHELL_RC/#$HOME/~}"
    touch "$SHELL_RC"

    local SAFE_URL SAFE_TOKEN TOML_URL
    SAFE_URL="${INPUT_URL//\'/\'\\\'\'}"
    SAFE_TOKEN="${INPUT_TOKEN//\'/\'\\\'\'}"
    TOML_URL="${INPUT_URL//\\/\\\\}"
    TOML_URL="${TOML_URL//\"/\\\"}"

    cat >> "$SHELL_RC" << EOF

${BLOCK_START}
export OPENAI_API_KEY='${SAFE_TOKEN}'
export OPENAI_BASE_URL='${SAFE_URL}'
${BLOCK_END}
EOF
    echo -e "  ${GREEN}✓${NC} Written to ${SHELL_RC_DISPLAY}"

    echo -e "\n${BLUE}[Step 4/4] Writing Codex config...${NC}"
    mkdir -p "$CODEX_CONFIG_DIR"
    cat > "$CODEX_CONFIG_FILE" << EOF
model = "gpt-5.4"
model_reasoning_effort = "medium"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "DevApi"

[model_providers.DevApi]
name = "DevApi"
base_url = "${TOML_URL}"
wire_api = "responses"
env_key = "OPENAI_API_KEY"
EOF
    echo -e "  ${GREEN}✓${NC} Written to ${CODEX_CONFIG_FILE/#$HOME/~}"

    echo -e "\n${CYAN}========================================${NC}"
    echo -e "  Written to ${SHELL_RC_DISPLAY}:"
    echo -e "  ${GREEN}OPENAI_BASE_URL${NC} = ${YELLOW}${INPUT_URL}${NC}"
    echo -e "  ${GREEN}OPENAI_API_KEY${NC} = ${YELLOW}******${NC}"
    echo -e "  ${GREEN}config.toml${NC}     = ${YELLOW}${CODEX_CONFIG_FILE/#$HOME/~}${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "\n${GREEN}[Success] Codex API configured!${NC}"
    print_source_reminder
}

# =============================================================================
# CLI parameter handling — direct subcommand execution
# =============================================================================

if [ $# -gt 0 ]; then
    case "$1" in
        install) do_install_codex ;;
        set-api) do_set_api ;;
        *) echo -e "${RED}[Error] Unknown command: $1${NC}"; exit 1 ;;
    esac
    exit 0
fi

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}======== BitsFactor Codex Setup v${VERSION} ========${NC}"
echo -e "Detected OS:   ${CYAN}${OS_TYPE}${NC}"
echo -e "Shell config:  ${CYAN}${SHELL_RC/#$HOME/~}${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
echo -e "  ${GREEN}1)${NC} Install Codex"
echo -e "  ${GREEN}2)${NC} Configure API"
echo -e "  ${RED}0)${NC} Exit"
echo ""
read -p "Enter option (0-2): " MENU_CHOICE < /dev/tty

case "$MENU_CHOICE" in
    1) do_install_codex ;;
    2) do_set_api ;;
    0|"")
        echo -e "${YELLOW}Exited.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] Invalid option: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
