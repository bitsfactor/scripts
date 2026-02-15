#!/bin/bash

# Define color output
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

echo -e "${BLUE}[Retrieve] Checking local SSH keys...${NC}"

# 1. Auto-detect or prompt to generate key
KEY_FILE=""
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    KEY_FILE="$HOME/.ssh/id_ed25519"
    echo -e "Found existing ed25519 key: ${YELLOW}$KEY_FILE${NC}"
elif [ -f "$HOME/.ssh/id_rsa" ]; then
    KEY_FILE="$HOME/.ssh/id_rsa"
    echo -e "Found existing rsa key: ${YELLOW}$KEY_FILE${NC}"
else
    echo -e "${YELLOW}[Notice] No SSH key detected.${NC}"
    read -p "❓ Would you like to automatically generate a secure ed25519 key? (y/n): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        KEY_FILE="$HOME/.ssh/id_ed25519"
        DEFAULT_EMAIL="$(whoami)@$(hostname)"
        
        echo -e "${BLUE}Generating silently...${NC}"
        ssh-keygen -t ed25519 -C "$DEFAULT_EMAIL" -f "$KEY_FILE" -N "" > /dev/null 2>&1
        echo -e "${GREEN}[Success] New key pair generated successfully!${NC}"
    else
        echo -e "${RED}[Cancelled] Generation cancelled. Exiting safely.${NC}"
        exit 1
    fi
fi

# 2. Print Public Key clearly on screen
echo -e "\n${CYAN}==================== [ Public Key ] =====================${NC}"
echo -e "${YELLOW}👉 Purpose: Add to GitHub (Settings -> SSH and GPG keys)${NC}"
cat "${KEY_FILE}.pub"
echo -e "${CYAN}=========================================================${NC}\n"

# 3. Print Private Key clearly on screen
echo -e "${CYAN}==================== [ Private Key ] ====================${NC}"
echo -e "${YELLOW}👉 Purpose: Paste into your VPS initialization script${NC}"
cat "${KEY_FILE}"
echo -e "${CYAN}=========================================================${NC}\n"

# 4. Auto-detect clipboard command (compatible with macOS/Linux/Windows)
CLIP_CMD=""
if command -v pbcopy &> /dev/null; then
    CLIP_CMD="pbcopy"
elif command -v xclip &> /dev/null; then
    CLIP_CMD="xclip -selection clipboard"
elif command -v wl-copy &> /dev/null; then
    CLIP_CMD="wl-copy"
elif command -v clip.exe &> /dev/null; then
    CLIP_CMD="clip.exe"
fi

# 5. Copy [Private Key] to clipboard by default
if [ -n "$CLIP_CMD" ]; then
    cat "$KEY_FILE" | $CLIP_CMD
    echo -e "${GREEN}[Success] Private Key automatically copied to your system clipboard!${NC}"
    echo -e "👉 Next, log into your VPS and run the remote init script. Press Cmd+V (or Ctrl+V) to paste when prompted."
else
    echo -e "${YELLOW}[Warning] No system clipboard tool detected. Please manually copy the Private Key above.${NC}"
fi
