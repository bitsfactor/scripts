#!/bin/bash

# =============================================================================
# Git SSH Key Management Tool
# Provides a menu to retrieve or set SSH keys for GitHub authentication.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash git.sh
#   curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/git.sh | bash
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
        read -p "Would you like to automatically generate a secure ed25519 key? (y/n): " confirm < /dev/tty

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            KEY_FILE="$HOME/.ssh/id_ed25519"
            local DEFAULT_EMAIL
            DEFAULT_EMAIL="$(whoami)@$(hostname)"

            echo -e "${BLUE}Generating silently...${NC}"
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"
            ssh-keygen -t ed25519 -C "$DEFAULT_EMAIL" -f "$KEY_FILE" -N "" > /dev/null 2>&1
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
    echo -e "${YELLOW}Purpose: Paste into your VPS initialization script${NC}"
    cat "${KEY_FILE}"
    echo -e "${CYAN}=========================================================${NC}\n"

    # Auto-detect clipboard command
    local CLIP_CMD=""
    if command -v pbcopy &> /dev/null; then
        CLIP_CMD="pbcopy"
    elif command -v xclip &> /dev/null; then
        CLIP_CMD="xclip -selection clipboard"
    elif command -v wl-copy &> /dev/null; then
        CLIP_CMD="wl-copy"
    elif command -v clip.exe &> /dev/null; then
        CLIP_CMD="clip.exe"
    fi

    # Copy Private Key to clipboard
    if [ -n "$CLIP_CMD" ]; then
        cat "$KEY_FILE" | $CLIP_CMD
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
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # Warn if key already exists
    if [ -f ~/.ssh/id_ed25519 ]; then
        echo -e "\n${YELLOW}[Warning] ~/.ssh/id_ed25519 already exists and will be overwritten.${NC}"
        read -p "Continue? (y/n): " overwrite_confirm < /dev/tty
        if [[ ! "$overwrite_confirm" =~ ^[Yy]$ ]]; then
            echo -e "${RED}[Cancelled] Operation cancelled.${NC}"
            return
        fi
    fi

    # Receive the Private Key
    echo -e "\n${YELLOW}=======================================================${NC}"
    echo -e "${YELLOW}Please paste your SSH Private Key below.${NC}"
    echo -e "${YELLOW}Press [Enter] for a new line, then press [Ctrl+D] to save.${NC}"
    echo -e "${YELLOW}=======================================================${NC}\n"

    cat /dev/tty > ~/.ssh/id_ed25519

    # Set strict permissions
    echo -e "\n${BLUE}[Step 2/4] Applying strict permissions (600)...${NC}"
    chmod 600 ~/.ssh/id_ed25519

    # Generate matching public key from private key
    echo -e "${BLUE}[Step 3/4] Generating matching public key...${NC}"
    if ! ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub 2>/dev/null; then
        echo -e "${RED}[Error] Invalid private key. Please check the key content and try again.${NC}"
        rm -f ~/.ssh/id_ed25519.pub
        return 1
    fi
    chmod 644 ~/.ssh/id_ed25519.pub

    # Add GitHub to known_hosts
    echo -e "${BLUE}[Step 4/4] Adding GitHub to trusted hosts...${NC}"
    if ! grep -q "^github.com " ~/.ssh/known_hosts 2>/dev/null; then
        ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
    fi

    # Verify Connection
    echo -e "${BLUE}Verifying GitHub connection...${NC}"

    local SSH_OUTPUT
    SSH_OUTPUT=$(ssh -T git@github.com 2>&1 || true)

    if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
        echo -e "${GREEN}[Success] GitHub authentication is configured perfectly!${NC}"
        echo -e "${GREEN}You can now securely 'git clone' your private repositories.${NC}"
    else
        echo -e "${RED}[Warning] GitHub verification failed. SSH response:${NC}"
        echo -e "${YELLOW}${SSH_OUTPUT}${NC}"
    fi
}

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}=== Git SSH Key Manager v${VERSION} ===${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
echo -e "  ${GREEN}1)${NC} Retrieve Keys (local machine)"
echo -e "  ${GREEN}2)${NC} Set Key (remote server / Mac)"
echo -e "  ${RED}0)${NC} Exit"
echo ""
read -p "Enter option (0/1/2): " MENU_CHOICE < /dev/tty

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
