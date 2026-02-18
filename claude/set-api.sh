#!/bin/bash

# =============================================================================
# Claude Code API 配置脚本
# 用途: 统一管理 Claude Code 的 API 配置，将所有配置写入 ~/.zshrc，
#       并清理 shell 配置文件和 settings.json 中的残留配置
# 支持幂等执行: 无论运行多少次，~/.zshrc 中只会存在一份配置
#
# 使用方式:
#   bash claude/set-api.sh
#   curl -s https://raw.githubusercontent.com/bitsfactor/scripts/main/claude/set-api.sh | bash
# =============================================================================

set -e

# 颜色定义
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

# 需要清理的变量列表
CLEAN_VARS=("ANTHROPIC_BASE_URL" "ANTHROPIC_AUTH_TOKEN" "ANTHROPIC_API_KEY" "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" "API_TIMEOUT_MS")

# 标记块标识
BLOCK_START="# >>> Claude Code API"
BLOCK_END="# <<< Claude Code API"

echo -e "${BLUE}=== Claude Code API 配置工具 ===${NC}"

# ---- Step 1/5: 检测操作系统 ----
echo -e "\n${BLUE}[Step 1/5] 检测操作系统...${NC}"

OS_TYPE=""
case "$OSTYPE" in
    darwin*)  OS_TYPE="macos" ;;
    linux*)   OS_TYPE="linux" ;;
    *)
        echo -e "${RED}[Error] 不支持的操作系统: $OSTYPE${NC}"
        echo -e "${YELLOW}此脚本仅支持 macOS 和 Linux.${NC}"
        exit 1
        ;;
esac
echo -e "检测到系统: ${CYAN}${OS_TYPE}${NC}"

# ---- Step 2/5: 提示用户输入 ----
echo -e "\n${BLUE}[Step 2/5] 请输入 API 配置信息...${NC}"

echo -e "${CYAN}请输入 ANTHROPIC_BASE_URL (API 地址):${NC}"
read -r INPUT_URL < /dev/tty

if [ -z "$INPUT_URL" ]; then
    echo -e "${RED}[Error] API 地址不能为空.${NC}"
    exit 1
fi

echo -e "${CYAN}请输入 ANTHROPIC_AUTH_TOKEN (API Key，输入时不会显示):${NC}"
read -rs INPUT_TOKEN < /dev/tty
echo ""

if [ -z "$INPUT_TOKEN" ]; then
    echo -e "${RED}[Error] API Key 不能为空.${NC}"
    exit 1
fi

echo -e "${GREEN}输入完成.${NC}"

# ---- Step 3/5: 扫描并清理旧配置 ----
echo -e "\n${BLUE}[Step 3/5] 扫描并清理旧配置...${NC}"

# sed_inplace: 跨平台 sed -i 封装
# 参数: $1 = sed 表达式, $2 = 文件路径
sed_inplace() {
    if [ "$OS_TYPE" = "macos" ]; then
        sed -i '' "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

# clean_shell_config: 清理单个 shell 配置文件
# 参数: $1 = 文件路径
clean_shell_config() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi

    local display_name="${file/#$HOME/~}"
    local cleaned=false

    # 1) 删除标记块（从 BLOCK_START 到 BLOCK_END 之间的所有内容）
    if grep -q "$BLOCK_START" "$file" 2>/dev/null; then
        sed_inplace "/$BLOCK_START/,/$BLOCK_END/d" "$file"
        cleaned=true
    fi

    # 2) 删除标记块外散落的相关 export 行
    for var in "${CLEAN_VARS[@]}"; do
        if grep -q "^export ${var}=" "$file" 2>/dev/null; then
            sed_inplace "/^export ${var}=/d" "$file"
            cleaned=true
        fi
    done

    if [ "$cleaned" = true ]; then
        echo -e "  ${GREEN}✓${NC} 已清理 ${display_name}"
    fi
}

# clean_settings_json: 清理 ~/.claude/settings.json 中 env 字段的相关 key
clean_settings_json() {
    local file="$HOME/.claude/settings.json"
    if [ ! -f "$file" ]; then
        return
    fi

    local cleaned=false

    for var in "${CLEAN_VARS[@]}"; do
        if grep -q "\"${var}\"" "$file" 2>/dev/null; then
            # 删除包含该变量名的行（匹配 "VAR_NAME": "..." 格式）
            grep -v "\"${var}\"" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
            cleaned=true
        fi
    done

    if [ "$cleaned" = true ]; then
        # 修复可能产生的 JSON 尾部逗号问题
        # 匹配: 行尾逗号后面紧跟 } 或 ] 的情况
        if [ "$OS_TYPE" = "macos" ]; then
            # 处理逗号后紧跟闭合括号的情况（可能跨行）
            perl -0777 -i -pe 's/,(\s*[}\]])/\1/g' "$file" 2>/dev/null || true
        else
            perl -0777 -i -pe 's/,(\s*[}\]])/\1/g' "$file" 2>/dev/null || true
        fi

        # 检查 env 对象是否为空，如果为空则删除整个 env 字段
        if grep -q '"env"' "$file" 2>/dev/null; then
            # 检测 env 对象内部是否还有内容（排除空白字符和括号）
            local env_content
            env_content=$(perl -0777 -ne 'if (/"env"\s*:\s*\{([^}]*)\}/) { print $1; }' "$file" 2>/dev/null || true)
            local trimmed
            trimmed=$(echo "$env_content" | tr -d '[:space:]')
            if [ -z "$trimmed" ]; then
                # env 为空，删除整个 env 字段
                perl -0777 -i -pe 's/,?\s*"env"\s*:\s*\{\s*\}//g' "$file" 2>/dev/null || true
                # 再次修复尾部逗号
                perl -0777 -i -pe 's/,(\s*[}\]])/\1/g' "$file" 2>/dev/null || true
            fi
        fi

        echo -e "  ${GREEN}✓${NC} 已清理 ~/.claude/settings.json 中的 env 配置"
    fi
}

# 执行清理
SHELL_CONFIGS=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")

for config in "${SHELL_CONFIGS[@]}"; do
    clean_shell_config "$config"
done

clean_settings_json

echo -e "  ${GREEN}旧配置清理完成.${NC}"

# ---- Step 4/5: 写入新配置到 ~/.zshrc ----
echo -e "\n${BLUE}[Step 4/5] 写入新配置到 ~/.zshrc...${NC}"

# 确保 ~/.zshrc 存在
touch "$HOME/.zshrc"

# 写入标记块
cat >> "$HOME/.zshrc" << EOF

# >>> Claude Code API 配置 (由 set-api.sh 设置) >>>
export ANTHROPIC_BASE_URL="${INPUT_URL}"
export ANTHROPIC_AUTH_TOKEN="${INPUT_TOKEN}"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
# <<< Claude Code API 配置 <<<
EOF

echo -e "  ${GREEN}✓${NC} 已写入 ~/.zshrc"

# ---- Step 5/5: 验证并提醒 ----
echo -e "\n${BLUE}[Step 5/5] 配置完成，请查看概要...${NC}"

echo -e "\n${CYAN}========================================${NC}"
echo -e "  已写入以下配置到 ~/.zshrc:"
echo -e "  ${GREEN}ANTHROPIC_BASE_URL${NC}  = ${YELLOW}${INPUT_URL}${NC}"
echo -e "  ${GREEN}ANTHROPIC_AUTH_TOKEN${NC} = ${YELLOW}******${NC}"
echo -e "  ${GREEN}CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC${NC} = ${YELLOW}1${NC}"
echo -e "${CYAN}========================================${NC}"

echo -e "\n${GREEN}[Success] Claude Code API 配置完成!${NC}"
echo -e "${YELLOW}[提醒] 请执行以下任一操作使配置生效:${NC}"
echo -e "  1. 重新打开终端窗口"
echo -e "  2. 手动执行: ${CYAN}source ~/.zshrc${NC}"
