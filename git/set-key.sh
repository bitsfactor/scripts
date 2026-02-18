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
echo -e "\n${BLUE}[Step 3/5] Applying strict permissions (600)...${NC}"
chmod 600 ~/.ssh/id_ed25519

# Step 4: 从私钥生成对应的公钥，覆盖旧的公钥文件，避免公私钥不匹配
echo -e "${BLUE}[Step 4/5] Generating matching public key...${NC}"
ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/id_ed25519.pub

# Step 5: Add GitHub to known_hosts to prevent interactive prompts
echo -e "${BLUE}[Step 5/5] Adding GitHub to trusted hosts...${NC}"
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

# Step 5: Verify Connection
echo -e "${BLUE}🔗 Verifying GitHub connection...${NC}"

# 捕获 ssh 输出，用于判断和展示
SSH_OUTPUT=$(ssh -T git@github.com 2>&1 || true)

if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo -e "${GREEN}[Success] GitHub authentication is configured perfectly!${NC}"
    echo -e "${GREEN}🎉 You can now securely 'git clone' your private repositories.${NC}"
else
    echo -e "${RED}[Warning] GitHub verification failed. SSH response:${NC}"
    echo -e "${YELLOW}${SSH_OUTPUT}${NC}"
fi
