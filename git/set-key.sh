#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define color output
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'
RED='\033[31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== VPS GitHub Authentication Setup ===${NC}"

# Step 1: Prepare SSH directory
echo -e "${BLUE}[Step 1/4] Preparing SSH directory...${NC}"
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Step 2: Receive the Private Key
echo -e "\n${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}🔑 Please paste your SSH Private Key below.${NC}"
echo -e "${YELLOW}👉 Press [Enter] for a new line, then press [Ctrl+D] to save.${NC}"
echo -e "${YELLOW}=======================================================${NC}\n"

# Capture multi-line input until Ctrl+D
# 使用 /dev/tty 从终端读取，确保 curl | bash 方式运行时也能正常接收输入
cat /dev/tty > ~/.ssh/id_ed25519

# Step 3: Set strict permissions (Required by SSH)
echo -e "\n${BLUE}[Step 3/4] Applying strict permissions (600)...${NC}"
chmod 600 ~/.ssh/id_ed25519

# Step 4: Add GitHub to known_hosts to prevent interactive prompts
echo -e "${BLUE}[Step 4/4] Adding GitHub to trusted hosts...${NC}"
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

# Step 5: Verify Connection
echo -e "${BLUE}🔗 Verifying GitHub connection...${NC}"

# Use ssh -T to test connection; grep to check for success message
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo -e "${GREEN}[Success] GitHub authentication is configured perfectly!${NC}"
    echo -e "${GREEN}🎉 You can now securely 'git clone' your private repositories.${NC}"
else
    echo -e "${RED}[Warning] The verification message was not completely clear, but the key is saved.${NC}"
    echo -e "${RED}Please try running a 'git clone' command to test the connection manually.${NC}"
fi
