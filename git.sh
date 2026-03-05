#!/bin/bash

# =============================================================================
# Git SSH Key Management Tool
# Provides a menu to retrieve or set SSH keys for GitHub authentication.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash git.sh
#   BFS_VER=1.3.1; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/git.sh | BFS_VER=$BFS_VER bash
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

# tty_read: read one line from /dev/tty
# Args: $1 = variable name to store result
#       $2 = (optional) prompt string (written directly to /dev/tty)
tty_read() {
    [ -n "$2" ] && printf '%s' "$2" > /dev/tty
    IFS= read -r "$1" < /dev/tty || true
}

# ensure_ssh_dir: create ~/.ssh with correct permissions if not present
ensure_ssh_dir() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
}

# =============================================================================
# 1) Retrieve Keys — detect or generate SSH key pair, copy to clipboard
# =============================================================================

do_get_key() {
    echo -e "\n${BLUE}=== Retrieve SSH Keys ===${NC}\n"

    echo -e "${BLUE}Checking local SSH keys...${NC}"

    # Auto-detect or prompt to generate key
    local KEY_FILE=""
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        KEY_FILE="$HOME/.ssh/id_ed25519"
        echo -e "Found existing ed25519 key: ${YELLOW}$KEY_FILE${NC}"
    elif [ -f "$HOME/.ssh/id_rsa" ]; then
        KEY_FILE="$HOME/.ssh/id_rsa"
        echo -e "Found existing rsa key: ${YELLOW}$KEY_FILE${NC}"
    else
        echo -e "${YELLOW}[Notice] No SSH key detected.${NC}"
        tty_read confirm "Would you like to automatically generate a secure ed25519 key? (y/n): "

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            KEY_FILE="$HOME/.ssh/id_ed25519"
            local DEFAULT_EMAIL
            DEFAULT_EMAIL="${USER}@${HOSTNAME}"

            echo -e "${BLUE}Generating silently...${NC}"
            ensure_ssh_dir
            if ! ssh-keygen -t ed25519 -C "$DEFAULT_EMAIL" -f "$KEY_FILE" -N "" > /dev/null 2>&1; then
                echo -e "${RED}[Error] Key generation failed.${NC}"
                return 1
            fi
            echo -e "${YELLOW}[Note] Key generated without a passphrase.${NC}"
            echo -e "${GREEN}[Success] New key pair generated successfully!${NC}"
        else
            echo -e "${RED}[Cancelled] Generation cancelled. Exiting safely.${NC}"
            return 1
        fi
    fi

    # Print Public Key
    echo -e "\n${CYAN}==================== [ Public Key ] =====================${NC}"
    echo -e "${YELLOW}Purpose: Add to GitHub (Settings -> SSH and GPG keys)${NC}"
    cat "${KEY_FILE}.pub"
    echo -e "${CYAN}=========================================================${NC}\n"

    # Print Private Key
    echo -e "${CYAN}==================== [ Private Key ] ====================${NC}"
    echo -e "${RED}[Security] Ensure terminal logging is disabled before proceeding.${NC}"
    echo -e "${YELLOW}Purpose: Paste into your VPS initialization script${NC}"
    cat "${KEY_FILE}"
    echo -e "${CYAN}=========================================================${NC}\n"

    # Auto-detect clipboard command
    local CLIP_CMD=()
    if command -v pbcopy &> /dev/null; then
        CLIP_CMD=(pbcopy)
    elif command -v xclip &> /dev/null; then
        CLIP_CMD=(xclip -selection clipboard)
    elif command -v wl-copy &> /dev/null; then
        CLIP_CMD=(wl-copy)
    elif command -v clip.exe &> /dev/null; then
        CLIP_CMD=(clip.exe)
    fi

    # Copy Private Key to clipboard
    if [ ${#CLIP_CMD[@]} -gt 0 ]; then
        "${CLIP_CMD[@]}" < "$KEY_FILE"
        echo -e "${GREEN}[Success] Private Key automatically copied to your system clipboard!${NC}"
        echo -e "Next, log into your VPS and run this script again with option 2). Press Cmd+V (or Ctrl+V) to paste when prompted."
    else
        echo -e "${YELLOW}[Warning] No system clipboard tool detected. Please manually copy the Private Key above.${NC}"
    fi
}

# =============================================================================
# 2) Set Key — receive private key, configure SSH, verify GitHub connection
# =============================================================================

do_set_key() {
    echo -e "\n${BLUE}=== Set SSH Key ===${NC}\n"

    # Prepare SSH directory
    echo -e "${BLUE}[Step 1/4] Preparing SSH directory...${NC}"
    ensure_ssh_dir

    # Receive the Private Key
    echo -e "\n${YELLOW}=======================================================${NC}"
    echo -e "${YELLOW}Please paste your SSH Private Key below.${NC}"
    echo -e "${YELLOW}(Auto-detects end of key, then press Enter to confirm.)${NC}"
    echo -e "${YELLOW}=======================================================${NC}\n"

    local TMP_KEY
    TMP_KEY=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$TMP_KEY'" EXIT
    trap 'exit 130' INT TERM
    chmod 600 "$TMP_KEY"
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        printf '%s\n' "$line"
        [[ "$line" == "-----END"*"-----" ]] && break
    done < /dev/tty > "$TMP_KEY"

    echo -e "\n${GREEN}Key received.${NC}"
    tty_read _confirm "Press Enter to continue (Ctrl+C to cancel): "

    if [ ! -s "$TMP_KEY" ]; then
        echo -e "${RED}[Error] No key data received.${NC}"
        rm -f "$TMP_KEY"
        trap - EXIT INT TERM
        return 1
    fi

    # Detect key type and determine target filename
    local KEY_FILE="$HOME/.ssh/id_ed25519"
    if grep -q "BEGIN RSA PRIVATE KEY" "$TMP_KEY"; then
        # PEM-format RSA key
        KEY_FILE="$HOME/.ssh/id_rsa"
    elif grep -q "BEGIN OPENSSH PRIVATE KEY" "$TMP_KEY"; then
        # Modern OpenSSH format — check actual key type from public key output
        local KEY_TYPE
        KEY_TYPE=$(ssh-keygen -y -f "$TMP_KEY" 2>/dev/null | awk '{print $1}' || true)
        [ "$KEY_TYPE" = "ssh-rsa" ] && KEY_FILE="$HOME/.ssh/id_rsa"
    fi

    # Warn if key already exists
    if [ -f "$KEY_FILE" ]; then
        echo -e "\n${YELLOW}[Warning] ${KEY_FILE/#$HOME/~} already exists and will be overwritten.${NC}"
        tty_read overwrite_confirm "Continue? (y/n): "
        if [[ ! "$overwrite_confirm" =~ ^[Yy]$ ]]; then
            echo -e "${RED}[Cancelled] Operation cancelled.${NC}"
            rm -f "$TMP_KEY"
            trap - EXIT INT TERM
            return
        fi
    fi

    # Move to final location with strict permissions
    echo -e "\n${BLUE}[Step 2/4] Applying strict permissions (600)...${NC}"
    mv "$TMP_KEY" "$KEY_FILE"
    trap - EXIT INT TERM
    chmod 600 "$KEY_FILE"

    # Generate matching public key from private key
    echo -e "${BLUE}[Step 3/4] Generating matching public key...${NC}"
    if ! ssh-keygen -y -f "$KEY_FILE" > "${KEY_FILE}.pub" 2>/dev/null; then
        echo -e "${RED}[Error] Invalid private key. Please check the key content and try again.${NC}"
        rm -f "${KEY_FILE}.pub" "$KEY_FILE"
        return 1
    fi
    chmod 644 "${KEY_FILE}.pub"

    # Add GitHub to known_hosts
    echo -e "${BLUE}[Step 4/4] Adding GitHub to trusted hosts...${NC}"
    if ! ssh-keygen -F github.com -f ~/.ssh/known_hosts > /dev/null 2>&1; then
        if ! ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null; then
            echo -e "  ${YELLOW}[Warning] Could not fetch GitHub host key. Verification may fail.${NC}"
        fi
    fi

    # Verify Connection
    echo -e "${BLUE}Verifying GitHub connection...${NC}"

    local SSH_OUTPUT
    SSH_OUTPUT=$(ssh -T git@github.com < /dev/null 2>&1 || true)

    if [[ "$SSH_OUTPUT" == *"successfully authenticated"* ]]; then
        echo -e "${GREEN}[Success] GitHub authentication is configured perfectly!${NC}"
        echo -e "${GREEN}You can now securely 'git clone' your private repositories.${NC}"
    else
        echo -e "${RED}[Warning] GitHub verification failed. SSH response:${NC}"
        echo -e "${YELLOW}${SSH_OUTPUT}${NC}"
    fi
}

# =============================================================================
# CLI parameter handling — direct subcommand execution
# =============================================================================

if [ $# -gt 0 ]; then
    case "$1" in
        get-key) do_get_key ;;
        set-key) do_set_key ;;
        *) echo -e "${RED}[Error] Unknown command: $1${NC}"; exit 1 ;;
    esac
    exit 0
fi

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}=== Git SSH Key Manager v${VERSION} ===${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
echo -e "  ${GREEN}1)${NC} Retrieve Keys (local machine)"
echo -e "  ${GREEN}2)${NC} Set Key (remote server / Mac)"
echo -e "  ${RED}0)${NC} Exit"
echo ""
stty sane < /dev/tty 2>/dev/null || true
tty_read MENU_CHOICE "Enter option (0/1/2): "

case "$MENU_CHOICE" in
    1) do_get_key ;;
    2) do_set_key ;;
    0|"")
        echo -e "${YELLOW}Exited.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] Invalid option: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
