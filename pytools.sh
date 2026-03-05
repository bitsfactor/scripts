#!/bin/bash

# =============================================================================
# BitsFactor PyTools Setup
# One-click deploy Python tools to ~/pytools, install deps, configure PATH.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash pytools.sh
#   curl -s https://fastly.jsdelivr.net/gh/bitsfactor/scripts@latest/pytools.sh | bash
# =============================================================================

set -e

# Version — synced from version.sh during release
VERSION="1.3.0"

# Load local version.sh override (for development)
_SCRIPT_DIR=""
[ -n "${BASH_SOURCE[0]}" ] && _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd 2>/dev/null)"
[ -n "$_SCRIPT_DIR" ] && [ -f "$_SCRIPT_DIR/version.sh" ] && . "$_SCRIPT_DIR/version.sh"

# CDN base URL — pinned to version tag (immutable, no purge needed)
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

# ---- Constants ----

CDN_PYTOOLS="${CDN_BASE}/pytools"
PYTOOLS_DIR="$HOME/pytools"
PYTOOLS_FILES=("dogecloud.py")
PYTOOLS_DEPS=("requests" "boto3")
VENV_DIR="$PYTOOLS_DIR/.venv"
PYTOOLS_BLOCK_START="# >>> BitsFactor pytools PATH"
PYTOOLS_BLOCK_END="# <<< BitsFactor pytools PATH"

# =============================================================================
# Shared functions
# =============================================================================

# has_path_block: check if a PATH block marker already exists in any shell config
# Args: $1 = block start marker string
# Returns: 0 if found, 1 if not found
has_path_block() {
    local marker="$1"
    local configs=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
    for cfg in "${configs[@]}"; do
        if [ -f "$cfg" ] && grep -qF "$marker" "$cfg" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

# write_path_block: append a PATH block to the shell RC file (idempotent)
# Uses printf instead of heredoc for curl|bash pipe compatibility.
# Args: $1 = block start marker, $2 = block end marker, $3 = block content lines
write_path_block() {
    local start="$1"
    local end="$2"
    local content="$3"
    local display="${SHELL_RC/#$HOME/~}"

    if has_path_block "$start"; then
        echo -e "  ${YELLOW}[Skip]${NC} PATH block already exists in shell config"
        return 0
    fi

    touch "$SHELL_RC"
    if [ -s "$SHELL_RC" ]; then
        printf '\n%s\n%s\n%s\n' "$start" "$content" "$end" >> "$SHELL_RC"
    else
        printf '%s\n%s\n%s\n' "$start" "$content" "$end" >> "$SHELL_RC"
    fi
    echo -e "  ${GREEN}✓${NC} Written PATH block to ${display}"
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

# sed_escape: escape a literal string for safe use as a sed BRE pattern
# Escapes: ] \ / . * ^ $ [
# Args: $1 = raw string
sed_escape() {
    printf '%s\n' "$1" | sed 's/[]\/.*^$[]/\\&/g'
}

# remove_path_block: remove the pytools PATH block from all shell config files
remove_path_block() {
    local configs=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
    local found=false
    local file esc_start esc_end
    esc_start=$(sed_escape "$PYTOOLS_BLOCK_START")
    esc_end=$(sed_escape "$PYTOOLS_BLOCK_END")
    for file in "${configs[@]}"; do
        if [ -f "$file" ] && grep -qF "$PYTOOLS_BLOCK_START" "$file" 2>/dev/null; then
            sed_inplace "/${esc_start}/,/${esc_end}/d" "$file"
            echo -e "  ${GREEN}✓${NC} Removed PATH block from ${file/#$HOME/~}"
            found=true
        fi
    done
    if [ "$found" = false ]; then
        echo -e "  ${YELLOW}[Skip]${NC} No PATH block found in shell configs"
    fi
}

# make_wrapper: generate a no-extension wrapper script for a .py tool
# Args: $1 = py filename (e.g. dogecloud.py)
make_wrapper() {
    local py_file="$1"
    local tool_name="${py_file%.py}"
    local wrapper_path="$PYTOOLS_DIR/$tool_name"

    printf '#!/bin/bash\nSCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"\nexec "$SCRIPT_DIR/.venv/bin/python3" "$SCRIPT_DIR/%s" "$@"\n' "$py_file" > "$wrapper_path"
    chmod +x "$wrapper_path"
    echo -e "  ${GREEN}✓${NC} Wrapper created: ~/pytools/${tool_name}"
}

# =============================================================================
# 1) Install / Update
# =============================================================================

do_install() {
    local url dest py_file

    # Detect install vs update based on whether venv already exists
    local is_update=false
    [ -d "$VENV_DIR" ] && is_update=true

    if [ "$is_update" = true ]; then
        echo -e "\n${BLUE}=== Update PyTools ===${NC}"
    else
        echo -e "\n${BLUE}=== Install PyTools ===${NC}"
    fi
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    # Step 1/6: Check python3
    echo -e "\n${BLUE}[Step 1/6] Checking python3...${NC}"
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}[Error] python3 is not installed.${NC}"
        echo -e "${YELLOW}Please install Python3 first (e.g. via env.sh).${NC}"
        return 1
    fi
    echo -e "  ${GREEN}✓${NC} $(python3 --version)"
    if ! python3 -c "import ensurepip" &>/dev/null; then
        if [ "$OS_TYPE" = "linux" ] && command -v apt-get &>/dev/null; then
            echo -e "  ${YELLOW}python3-venv not found. Installing...${NC}"
            local SUDO=""
            [ "$(id -u)" -ne 0 ] && SUDO="sudo"
            $SUDO apt-get update -qq || return 1
            if ! $SUDO apt-get install -y python3-venv --quiet; then
                echo -e "  ${RED}[Error] Failed to install python3-venv.${NC}"
                return 1
            fi
            echo -e "  ${GREEN}✓${NC} python3-venv installed"
        else
            echo -e "${RED}[Error] python3-venv is not available.${NC}"
            echo -e "${YELLOW}On Debian/Ubuntu, run: sudo apt-get install python3-venv${NC}"
            return 1
        fi
    fi

    # Step 2/6: Create ~/pytools/
    echo -e "\n${BLUE}[Step 2/6] Preparing ~/pytools/ directory...${NC}"
    mkdir -p "$PYTOOLS_DIR"
    echo -e "  ${GREEN}✓${NC} Directory ready: ${YELLOW}${PYTOOLS_DIR}${NC}"

    # Step 3/6: Download tools and create wrappers
    echo -e "\n${BLUE}[Step 3/6] Downloading tools...${NC}"
    for py_file in "${PYTOOLS_FILES[@]}"; do
        url="${CDN_PYTOOLS}/${py_file}"
        dest="${PYTOOLS_DIR}/${py_file}"
        echo -e "  Downloading ${CYAN}${py_file}${NC}..."
        if ! curl -fsSL "$url" -o "$dest"; then
            echo -e "  ${RED}[Error] Failed to download ${py_file}${NC}"
            return 1
        fi
        chmod +x "$dest"
        echo -e "  ${GREEN}✓${NC} Downloaded: ~/pytools/${py_file}"
        make_wrapper "$py_file"
    done

    # Step 4/6: Create / update virtual environment
    if [ "$is_update" = true ]; then
        echo -e "\n${BLUE}[Step 4/6] Updating virtual environment...${NC}"
    else
        echo -e "\n${BLUE}[Step 4/6] Creating virtual environment...${NC}"
    fi
    if ! python3 -m venv "$VENV_DIR"; then
        echo -e "  ${RED}[Error] Failed to create virtual environment.${NC}"
        echo -e "  ${YELLOW}On Debian/Ubuntu, run: sudo apt-get install python3-venv${NC}"
        return 1
    fi
    echo -e "  ${GREEN}✓${NC} Venv ready: ~/pytools/.venv/"

    # Step 5/6: Install / upgrade Python dependencies into venv
    if [ "$is_update" = true ]; then
        echo -e "\n${BLUE}[Step 5/6] Upgrading Python dependencies in venv...${NC}"
    else
        echo -e "\n${BLUE}[Step 5/6] Installing Python dependencies into venv...${NC}"
    fi
    echo -e "  Dependencies: ${CYAN}${PYTOOLS_DEPS[*]}${NC}"
    if [ "$is_update" = true ]; then
        if ! "$VENV_DIR/bin/pip" install "${PYTOOLS_DEPS[@]}" --upgrade --quiet; then
            echo -e "  ${RED}[Error] pip upgrade failed. Please check your Python environment.${NC}"
            return 1
        fi
        echo -e "  ${GREEN}✓${NC} Dependencies upgraded in venv"
    else
        if ! "$VENV_DIR/bin/pip" install "${PYTOOLS_DEPS[@]}" --quiet; then
            echo -e "  ${RED}[Error] pip install failed. Please check your Python environment.${NC}"
            return 1
        fi
        echo -e "  ${GREEN}✓${NC} Dependencies installed into venv"
    fi

    # Step 6/6: Configure PATH
    echo -e "\n${BLUE}[Step 6/6] Configuring PATH...${NC}"
    local pytools_content='export PATH="$HOME/pytools:$PATH"'
    write_path_block "$PYTOOLS_BLOCK_START" "$PYTOOLS_BLOCK_END" "$pytools_content"

    local display="${SHELL_RC/#$HOME/~}"
    if [ "$is_update" = true ]; then
        echo -e "\n${GREEN}[Success] PyTools updated!${NC}"
    else
        echo -e "\n${GREEN}[Success] PyTools installed!${NC}"
    fi
    if [ "$is_update" = false ]; then
        echo -e "${YELLOW}[Reminder] To apply PATH changes in your current terminal:${NC}"
        echo -e "  ${CYAN}source ${display}${NC}"
    fi
    echo -e "\nAvailable commands:"
    for py_file in "${PYTOOLS_FILES[@]}"; do
        echo -e "  ${GREEN}${py_file%.py}${NC}"
    done
}

# =============================================================================
# 2) Uninstall
# =============================================================================

do_uninstall() {
    echo -e "\n${BLUE}=== Uninstall PyTools ===${NC}"

    echo -e "\n${YELLOW}[Warning] This will remove ~/pytools/ and PATH config from shell RC files.${NC}"
    read -p "Continue? (y/n): " CONFIRM < /dev/tty
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[Cancelled] Operation cancelled.${NC}"
        return
    fi

    # Step 1/2: Remove ~/pytools/
    echo -e "\n${BLUE}[Step 1/2] Removing ~/pytools/...${NC}"
    if [ -d "$PYTOOLS_DIR" ]; then
        rm -rf "$PYTOOLS_DIR"
        echo -e "  ${GREEN}✓${NC} Removed ~/pytools/"
    else
        echo -e "  ${YELLOW}[Skip]${NC} ~/pytools/ does not exist"
    fi

    # Step 2/2: Remove PATH block from shell configs
    echo -e "\n${BLUE}[Step 2/2] Cleaning shell config entries...${NC}"
    remove_path_block

    echo -e "\n${GREEN}[Success] PyTools uninstalled.${NC}"
    echo -e "${YELLOW}[Reminder] Restart your terminal or run:${NC}"
    echo -e "  ${CYAN}source ${SHELL_RC/#$HOME/~}${NC}"
}

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}=== BitsFactor PyTools v${VERSION} ===${NC}"
echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
echo -e "  ${GREEN}1)${NC} Install / Update"
echo -e "  ${RED}2)${NC} Uninstall"
echo -e "  ${RED}0)${NC} Exit"
echo ""
read -p "Enter option (0/1/2): " MENU_CHOICE < /dev/tty

case "$MENU_CHOICE" in
    1) do_install ;;
    2) do_uninstall ;;
    0|"")
        echo -e "${YELLOW}Exited.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] Invalid option: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
