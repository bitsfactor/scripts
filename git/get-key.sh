#!/bin/bash

# 定义颜色输出
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

echo -e "${BLUE}[Retrieve] 正在检查本地 SSH 密钥...${NC}"

# 1. 自动探测或询问生成密钥
KEY_FILE=""
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    KEY_FILE="$HOME/.ssh/id_ed25519"
    echo -e "发现现有 ed25519 密钥: ${YELLOW}$KEY_FILE${NC}"
elif [ -f "$HOME/.ssh/id_rsa" ]; then
    KEY_FILE="$HOME/.ssh/id_rsa"
    echo -e "发现现有 rsa 密钥: ${YELLOW}$KEY_FILE${NC}"
else
    echo -e "${YELLOW}[Notice] 未检测到 SSH 密钥。${NC}"
    read -p "❓ 是否自动为你生成最安全的 ed25519 密钥？(y/n): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        KEY_FILE="$HOME/.ssh/id_ed25519"
        DEFAULT_EMAIL="$(whoami)@$(hostname)"
        
        echo -e "${BLUE}正在静默生成...${NC}"
        ssh-keygen -t ed25519 -C "$DEFAULT_EMAIL" -f "$KEY_FILE" -N "" > /dev/null 2>&1
        echo -e "${GREEN}[Success] 全新密钥对已生成！${NC}"
    else
        echo -e "${RED}[Cancelled] 已取消生成。脚本安全退出。${NC}"
        exit 1
    fi
fi

# 2. 在屏幕上清晰打印公钥 (Public Key)
echo -e "\n${CYAN}================== [ 公钥 Public Key ] ==================${NC}"
echo -e "${YELLOW}👉 作用: 用于在 GitHub (Settings -> SSH keys) 中添加信任${NC}"
cat "${KEY_FILE}.pub"
echo -e "${CYAN}=========================================================${NC}\n"

# 3. 在屏幕上清晰打印私钥 (Private Key)
echo -e "${CYAN}================== [ 私钥 Private Key ] =================${NC}"
echo -e "${YELLOW}👉 作用: 用于粘贴到你 VPS 的初始化脚本中${NC}"
cat "${KEY_FILE}"
echo -e "${CYAN}=========================================================${NC}\n"

# 4. 自动探测剪贴板命令 (兼容 macOS/Linux/Windows)
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

# 5. 将【私钥】默认写入剪贴板 (为了最高效的 VPS 部署)
if [ -n "$CLIP_CMD" ]; then
    cat "$KEY_FILE" | $CLIP_CMD
    echo -e "${GREEN}[Success] 私钥 (Private Key) 已自动存入你的系统剪贴板！${NC}"
    echo -e "👉 接下来，请登录你的 VPS 并运行远端初始化脚本。遇到提示时直接按下 Command+V 粘贴即可。"
else
    echo -e "${YELLOW}[Warning] 未检测到系统剪贴板工具，请手动复制上方的私钥内容。${NC}"
fi
