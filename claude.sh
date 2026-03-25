#!/bin/bash

# =============================================================================
# Claude Code Setup Tool
# All-in-one menu: install / update, configure API, or uninstall Claude Code.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash claude.sh
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

# ---- Shared variables for API config cleanup ----

DEFAULT_BASE_URL="https://api.develop.cc"
CLEAN_VARS=("ANTHROPIC_BASE_URL" "ANTHROPIC_AUTH_TOKEN" "ANTHROPIC_API_KEY" "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" "API_TIMEOUT_MS")
BLOCK_START="# >>> Claude Code API"
BLOCK_END="# <<< Claude Code API"

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
    if grep -qF "$BLOCK_START" "$file" 2>/dev/null; then
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
# 纯 shell 实现：sed 删除目标 key 行，awk 修复 JSON 格式（尾逗号、空 env 块）
clean_settings_json() {
    local file="$HOME/.claude/settings.json"
    if [ ! -f "$file" ]; then
        return
    fi

    # 检查文件中是否存在目标 key
    local has_keys=false
    for var in "${CLEAN_VARS[@]}"; do
        if grep -q "\"${var}\"" "$file" 2>/dev/null; then
            has_keys=true
            break
        fi
    done

    if [ "$has_keys" = false ]; then
        return
    fi

    # 删除包含目标 key 的行（单次 sed 调用，锚定匹配避免误删）
    # 注：此处不用 sed_inplace，因需传递数组形式的多个 -e 参数，该工具函数不支持
    local _sed_args=()
    for var in "${CLEAN_VARS[@]}"; do
        _sed_args+=(-e "/^[[:space:]]*\"${var}\"[[:space:]]*:/d")
    done
    if [ "$OS_TYPE" = "macos" ]; then
        sed -i '' "${_sed_args[@]}" "$file"
    else
        sed -i "${_sed_args[@]}" "$file"
    fi

    # 用 awk 修复 JSON 格式：移除空 env 块、修复尾逗号
    local tmp
    tmp=$(mktemp)
    trap "rm -f '$tmp'" RETURN

    awk '
    { lines[NR] = $0 }
    END {
        n = NR

        # 第一轮：移除空 "env": { } 块
        for (i = 1; i <= n; i++) {
            if (lines[i] ~ /"env"[[:space:]]*:[[:space:]]*\{[[:space:]]*$/) {
                j = i + 1
                while (j <= n && lines[j] ~ /^[[:space:]]*$/) j++
                if (j <= n && lines[j] ~ /^[[:space:]]*\},?[[:space:]]*$/) {
                    for (k = i; k <= j; k++) lines[k] = ""
                }
            }
        }

        # 第二轮：修复尾逗号（逗号后紧跟 } 或 ]）
        for (i = 1; i <= n; i++) {
            if (lines[i] == "") continue
            if (lines[i] ~ /,$/) {
                j = i + 1
                while (j <= n && (lines[j] == "" || lines[j] ~ /^[[:space:]]*$/)) j++
                if (j <= n && lines[j] ~ /^[[:space:]]*[}\]]/) {
                    sub(/,$/, "", lines[i])
                }
            }
        }

        # 输出非空行
        for (i = 1; i <= n; i++) {
            if (lines[i] != "") print lines[i]
        }
    }
    ' "$file" > "$tmp"

    # 检查 awk 输出非空，避免用空文件覆盖原文件
    if [ ! -s "$tmp" ]; then
        echo -e "  ${YELLOW}[Warning] Failed to process ~/.claude/settings.json${NC}"
        return
    fi

    if mv "$tmp" "$file"; then
        echo -e "  ${GREEN}✓${NC} Cleaned ~/.claude/settings.json env entries"
    else
        echo -e "  ${YELLOW}[Warning] Failed to update ~/.claude/settings.json${NC}"
    fi
}

# _backup_settings_json: backup ~/.claude/settings.json and reset to {}
# Args: $1 = warning message
_backup_settings_json() {
    local file="$HOME/.claude/settings.json"
    local bak_name="settings.json.bak.$(date +%Y%m%d%H%M%S)"
    cp "$file" "$HOME/.claude/${bak_name}"
    echo '{}' > "$file"
    echo -e "  ${YELLOW}[Warning] $1${NC}"
    echo -e "  ${YELLOW}Backed up to ${bak_name} and reset to {}.${NC}"
}

# repair_settings_json: 检测并修复 ~/.claude/settings.json 的 JSON 格式问题
# 修复策略：空文件写入 {}，非空文件移除空行/修复尾逗号，括号不配对则备份并重建
repair_settings_json() {
    local file="$HOME/.claude/settings.json"

    # 文件不存在 → 跳过
    if [ ! -f "$file" ]; then
        return
    fi

    # 文件为空 → 写入 {}
    if [ ! -s "$file" ]; then
        echo '{}' > "$file"
        echo -e "  ${GREEN}✓${NC} Repaired ~/.claude/settings.json (was empty, wrote {})"
        return
    fi

    # 文件非空 → 用 awk 修复
    local tmp
    tmp=$(mktemp)
    trap "rm -f '$tmp'" RETURN

    awk '
    # 跳过空行
    /^[[:space:]]*$/ { next }

    { lines[++n] = $0 }

    END {
        # 修复尾逗号（逗号后紧跟 } 或 ]）
        for (i = 1; i <= n; i++) {
            if (lines[i] ~ /,$/) {
                j = i + 1
                if (j <= n && lines[j] ~ /^[[:space:]]*[}\]]/) {
                    sub(/,$/, "", lines[i])
                }
            }
        }

        # 输出所有行
        for (i = 1; i <= n; i++) {
            print lines[i]
        }
    }
    ' "$file" > "$tmp"

    # awk 输出为空（文件全是空白行）→ 视为无法修复，备份并重建
    if [ ! -s "$tmp" ]; then
        _backup_settings_json "~/.claude/settings.json had no valid content."
        return
    fi

    # 检查 JSON 是否有效：优先用 python3 精确解析，不可用时降级为括号计数
    local is_valid_json=true
    if command -v python3 &>/dev/null; then
        python3 -c "import json,sys; json.load(sys.stdin)" < "$tmp" 2>/dev/null || is_valid_json=false
    else
        local open_braces close_braces open_brackets close_brackets
        read -r open_braces close_braces open_brackets close_brackets < <(awk '
            {o+=gsub(/{/,""); c+=gsub(/}/,""); ob+=gsub(/\[/,""); cb+=gsub(/\]/,"")}
            END {print o+0, c+0, ob+0, cb+0}
        ' "$tmp")
        if [ "$open_braces" -ne "$close_braces" ] || [ "$open_brackets" -ne "$close_brackets" ]; then
            is_valid_json=false
        fi
    fi

    if [ "$is_valid_json" = false ]; then
        _backup_settings_json "~/.claude/settings.json had invalid JSON."
        return
    fi

    # 比较修复前后是否有变化
    if ! cmp -s "$file" "$tmp"; then
        if mv "$tmp" "$file"; then
            echo -e "  ${GREEN}✓${NC} Repaired ~/.claude/settings.json (fixed formatting)"
        else
            rm -f "$tmp"
            echo -e "  ${YELLOW}[Warning] Failed to write repaired settings.json${NC}"
        fi
    fi
}

# clean_all_shell_configs: clean all known shell config files
clean_all_shell_configs() {
    local SHELL_CONFIGS=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
    for config in "${SHELL_CONFIGS[@]}"; do
        clean_shell_config "$config"
    done
}

# run_official_installer: 下载并执行官方安装脚本
# 用于 install 和 update (other 方式) 的公共逻辑
run_official_installer() {
    local tmp_installer
    tmp_installer=$(mktemp)
    if ! curl -fsSL https://claude.ai/install.sh -o "$tmp_installer"; then
        echo -e "${RED}[Error] Failed to download installer.${NC}"
        rm -f "$tmp_installer"
        return 1
    fi
    bash "$tmp_installer" || { rm -f "$tmp_installer"; return 1; }
    rm -f "$tmp_installer"
}

# detect_install_method: 检测 Claude Code 的安装方式
# 设置全局变量 INSTALL_METHOD: "npm" / "homebrew" / "other" / ""
# 同时设置 CLAUDE_PATH（仅 other 方式时有值）
detect_install_method() {
    INSTALL_METHOD=""
    CLAUDE_PATH=""

    if [ "$OS_TYPE" = "macos" ] && command -v brew &>/dev/null && brew list --cask claude-code &>/dev/null; then
        INSTALL_METHOD="homebrew"
        echo -e "Detected: ${CYAN}Homebrew Cask${NC}"
    elif command -v claude &>/dev/null; then
        CLAUDE_PATH=$(command -v claude)
        # 官方安装脚本下载预编译二进制，安装到 ~/.local/bin/，不经过 npm
        # 用 npm 全局前缀比对路径，确保只有真正通过 npm install -g 的二进制才被识别为 npm
        local _npm_prefix=""
        if command -v npm &>/dev/null; then
            _npm_prefix=$(npm prefix -g 2>/dev/null || true)
        fi
        if [ -n "$_npm_prefix" ] && [[ "$CLAUDE_PATH" == "${_npm_prefix}/bin/"* ]]; then
            INSTALL_METHOD="npm"
            echo -e "Detected: ${CYAN}NPM global install${NC}"
        else
            INSTALL_METHOD="other"
            echo -e "Detected: ${CYAN}Official installer / manual${NC}"
            echo -e "Binary path: ${YELLOW}${CLAUDE_PATH}${NC}"
        fi
    else
        echo -e "${YELLOW}[Notice] Claude Code installation not detected.${NC}"
    fi
}

# ensure_local_bin_in_path: 若 ~/.local/bin 未在 shell 配置中，自动添加 PATH 导出
ensure_local_bin_in_path() {
    local local_bin="$HOME/.local/bin"
    # 已在配置文件中则跳过（避免重复写入）
    if grep -qF '$HOME/.local/bin' "$SHELL_RC" 2>/dev/null; then
        return 0
    fi
    # 写入 shell 配置文件
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$SHELL_RC"
    echo -e "${GREEN}[Success] Added ~/.local/bin to PATH in ${SHELL_RC}${NC}"
    # 同步更新当前会话 PATH，使 claude --version 立即可用
    export PATH="$local_bin:$PATH"
    _PATH_WRITTEN=true
}

# print_source_reminder: 打印醒目的 source 提示框
print_source_reminder() {
    local rc_display="${SHELL_RC/#$HOME/~}"
    echo -e "\n${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Apply changes in your current terminal:${NC}"
    echo
    echo -e "    ${CYAN}source ${rc_display}${NC}"
    echo
    echo -e "${YELLOW}  Or simply reopen your terminal window.${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
}

# =============================================================================
# 1) Install / Update Claude Code
# =============================================================================

do_install() {
    _PATH_WRITTEN=false
    echo -e "\n${BLUE}=== Install / Update Claude Code ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    # ---- Repair settings.json ----
    echo -e "\n${BLUE}[Step 1/3] Checking settings.json...${NC}"

    repair_settings_json

    # ---- Detect install method ----
    echo -e "\n${BLUE}[Step 2/3] Detecting install method...${NC}"

    detect_install_method

    # ---- Install or update ----
    echo -e "\n${BLUE}[Step 3/3] Installing / updating Claude Code...${NC}"

    if [ -z "$INSTALL_METHOD" ]; then
        echo -e "No existing installation found. Installing via official installer...\n"
        if ! run_official_installer; then
            return 1
        fi
        ensure_local_bin_in_path
    else
        case "$INSTALL_METHOD" in
            npm)
                echo -e "Updating via NPM..."
                if npm install -g @anthropic-ai/claude-code@latest; then
                    echo -e "${GREEN}[Success] NPM update complete.${NC}"
                else
                    echo -e "${YELLOW}[Warning] NPM update failed, trying sudo...${NC}"
                    if sudo npm install -g @anthropic-ai/claude-code@latest; then
                        echo -e "${GREEN}[Success] NPM update complete (sudo).${NC}"
                    else
                        echo -e "${RED}[Error] NPM update failed.${NC}"
                        return 1
                    fi
                fi
                ;;
            homebrew)
                echo -e "Updating via Homebrew..."
                if brew upgrade --cask claude-code; then
                    echo -e "${GREEN}[Success] Homebrew upgrade complete.${NC}"
                else
                    echo -e "${RED}[Error] Homebrew upgrade failed.${NC}"
                    return 1
                fi
                ;;
            other)
                echo -e "Updating via official installer...\n"
                if ! run_official_installer; then
                    return 1
                fi
                ensure_local_bin_in_path
                ;;
        esac
    fi

    # ---- Show version ----
    echo -e "\n${CYAN}Current version:${NC}"
    claude --version 2>/dev/null || echo -e "${YELLOW}[Warning] Could not retrieve version.${NC}"

    echo -e "\n${GREEN}[Success] Claude Code is ready!${NC}"
    if [ "$_PATH_WRITTEN" = true ]; then
        print_source_reminder
    fi
}

# =============================================================================
# 2) Set API — configure ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN
# =============================================================================

do_set_api() {
    echo -e "\n${BLUE}=== Configure Claude Code API ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    # ---- Repair settings.json ----
    echo -e "\n${BLUE}[Step 1/5] Checking settings.json...${NC}"

    repair_settings_json

    # ---- Prompt for input ----
    echo -e "\n${BLUE}[Step 2/5] Enter API configuration...${NC}"

    echo -e "${CYAN}Enter ANTHROPIC_BASE_URL (API endpoint) [${DEFAULT_BASE_URL}]:${NC}"
    tty_read INPUT_URL
    : "${INPUT_URL:=$DEFAULT_BASE_URL}"

    # Auto-prepend https:// if no protocol specified
    if [[ "$INPUT_URL" != http://* ]] && [[ "$INPUT_URL" != https://* ]]; then
        INPUT_URL="https://${INPUT_URL}"
        echo -e "${YELLOW}[Auto] Added https:// prefix → ${INPUT_URL}${NC}"
    fi

    echo -e "${CYAN}Enter ANTHROPIC_AUTH_TOKEN (API key):${NC}"
    tty_read INPUT_TOKEN

    if [ -z "$INPUT_TOKEN" ]; then
        echo -e "${RED}[Error] API key cannot be empty.${NC}"
        return 1
    fi

    echo -e "${GREEN}Input received.${NC}"

    # ---- Clean old config ----
    echo -e "\n${BLUE}[Step 3/5] Cleaning old configuration...${NC}"

    clean_all_shell_configs
    clean_settings_json

    echo -e "  ${GREEN}Old config cleanup done.${NC}"

    # ---- Write new config to shell RC file ----
    local SHELL_RC_DISPLAY="${SHELL_RC/#$HOME/~}"
    echo -e "\n${BLUE}[Step 4/5] Writing new config to ${SHELL_RC_DISPLAY}...${NC}"

    touch "$SHELL_RC"

    # 转义单引号，防止值中含单引号破坏生成的 shell 语句
    local SAFE_URL SAFE_TOKEN
    SAFE_URL="${INPUT_URL//\'/\'\\\'\'}"
    SAFE_TOKEN="${INPUT_TOKEN//\'/\'\\\'\'}"

    cat >> "$SHELL_RC" << EOF

${BLOCK_START}
export ANTHROPIC_BASE_URL='${SAFE_URL}'
export ANTHROPIC_AUTH_TOKEN='${SAFE_TOKEN}'
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
${BLOCK_END}
EOF

    echo -e "  ${GREEN}✓${NC} Written to ${SHELL_RC_DISPLAY}"

    # ---- Summary ----
    echo -e "\n${BLUE}[Step 5/5] Configuration summary...${NC}"

    echo -e "\n${CYAN}========================================${NC}"
    echo -e "  Written to ${SHELL_RC_DISPLAY}:"
    echo -e "  ${GREEN}ANTHROPIC_BASE_URL${NC}  = ${YELLOW}${INPUT_URL}${NC}"
    echo -e "  ${GREEN}ANTHROPIC_AUTH_TOKEN${NC} = ${YELLOW}******${NC}"
    echo -e "  ${GREEN}CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC${NC} = ${YELLOW}1${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "\n${GREEN}[Success] Claude Code API configured!${NC}"
    print_source_reminder
}

# =============================================================================
# 3) Trust All Tools — write permission settings and cc alias
# =============================================================================

do_trust_all() {
    echo -e "\n${BLUE}=== Trust All Tools ===${NC}"

    if [ "$(id -u)" = "0" ]; then
        echo -e "\n${YELLOW}[Notice] Running as root — will use full tool allowlist.${NC}"
    fi

    # ---- Check python3 ----
    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}[Error] python3 is required but not found. Install it and retry.${NC}"
        return 1
    fi

    local total_steps=2
    [ "$OS_TYPE" = "macos" ] && total_steps=3

    # ---- Ensure ~/.claude/settings.json ----
    echo -e "\n${BLUE}[Step 1/${total_steps}] Checking settings.json...${NC}"
    mkdir -p "$HOME/.claude"
    local file="$HOME/.claude/settings.json"
    if [ ! -f "$file" ]; then
        echo '{}' > "$file"
        echo -e "  ${GREEN}✓${NC} Created ~/.claude/settings.json"
    else
        repair_settings_json
    fi

    # ---- Write trust-all settings ----
    echo -e "\n${BLUE}[Step 2/${total_steps}] Writing trust-all settings...${NC}"

    local tmp_py
    tmp_py=$(mktemp)
    trap "rm -f '$tmp_py'" RETURN

    cat > "$tmp_py" << 'PYEOF'
import json, sys

file = sys.argv[1]
with open(file) as f:
    data = json.load(f)

changes = []

# Remove legacy bypassPermissions settings
if "skipDangerousModePermissionPrompt" in data:
    del data["skipDangerousModePermissionPrompt"]
    changes.append("removedLegacy")

# Set full tool allowlist (works for both root and non-root)
perms = data.setdefault("permissions", {})
all_tools = ["Bash", "Read", "Edit", "Write", "WebFetch", "WebSearch",
             "Glob", "Grep", "NotebookEdit", "Agent", "MCP"]

if sorted(perms.get("allow", [])) != sorted(all_tools):
    perms["allow"] = all_tools
    changes.append("allowAll")

with open(file, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(",".join(changes) if changes else "already")
PYEOF

    local result
    result=$(python3 "$tmp_py" "$file") || {
        echo -e "${RED}[Error] Failed to update settings.json.${NC}"
        return 1
    }

    if [ "$result" = "already" ]; then
        echo -e "  ${CYAN}Already set — no changes needed.${NC}"
    else
        [[ "$result" == *allowAll* ]] && \
            echo -e "  ${GREEN}✓${NC} permissions.allow = all tools"
        [[ "$result" == *removedLegacy* ]] && \
            echo -e "  ${GREEN}✓${NC} Removed legacy bypassPermissions settings"
    fi

    # ---- macOS: add cc alias ----
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BLUE}[Step 3/${total_steps}] Setting up 'cc' alias...${NC}"

        local ALIAS_LINE="alias cc='claude --dangerously-skip-permissions'"

        # Remove existing cc alias to avoid duplicates
        if grep -q "^alias cc=" "$SHELL_RC" 2>/dev/null; then
            sed_inplace "/^alias cc=/d" "$SHELL_RC"
        fi

        echo "$ALIAS_LINE" >> "$SHELL_RC"
        echo -e "  ${GREEN}✓${NC} Added alias: ${CYAN}cc${NC} → claude --dangerously-skip-permissions"

        echo -e "\n${GREEN}[Success] Permission prompts will no longer appear.${NC}"
        print_source_reminder
    else
        echo -e "\n${GREEN}[Success] Permission prompts will no longer appear.${NC}"
        echo -e "${CYAN}Restart Claude Code to apply.${NC}"
    fi
}

# =============================================================================
# 4) Uninstall Claude Code — detect install method, remove binary and configs
# =============================================================================

do_uninstall() {
    echo -e "\n${BLUE}=== Uninstall Claude Code ===${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"

    # ---- Confirmation ----
    echo -e "\n${YELLOW}[Warning] This will uninstall Claude Code and remove related config.${NC}"
    tty_read CONFIRM "Continue? (y/n): "
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[Cancelled] Operation cancelled.${NC}"
        return
    fi

    # ---- Detect install method ----
    echo -e "\n${BLUE}[Step 1/6] Detecting install method...${NC}"

    detect_install_method

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

    for bf in "$HOME"/.claude.json.backup.*; do
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
        if [ -f "$rc" ] && grep -qF "$BLOCK_START" "$rc" 2>/dev/null; then
            HAS_SHELL_CONFIG=true
            echo -e "  ${YELLOW}${rc/#$HOME/~}${NC} (API env vars)"
        fi
    done

    if [ ${#ITEMS_TO_CLEAN[@]} -eq 0 ] && [ "$HAS_SHELL_CONFIG" = false ]; then
        if [ -z "$INSTALL_METHOD" ]; then
            echo -e "\n${GREEN}[Success] No Claude Code installation or config found.${NC}"
            echo -e "Nothing to clean."
            return
        fi
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
        tty_read USER_CHOICE "Enter option (0/1/2): "

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
        tty_read CONFIRM2 "Confirm? (y/n): "
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
                local REMOVED_BIN=false

                if [ -n "$CLAUDE_PATH" ]; then
                    if rm "$CLAUDE_PATH" 2>/dev/null || sudo rm "$CLAUDE_PATH" 2>/dev/null; then
                        echo -e "${GREEN}[Success] Removed ${CLAUDE_PATH}${NC}"
                        REMOVED_BIN=true
                    else
                        echo -e "${RED}[Error] Cannot remove ${CLAUDE_PATH}${NC}"
                    fi
                fi

                # 避免与 CLAUDE_PATH 重复删除同一文件
                if [ -f "$HOME/.local/bin/claude" ] && [ "$CLAUDE_PATH" != "$HOME/.local/bin/claude" ]; then
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
            echo -e "  ${RED}✗${NC} claude command still exists: $(command -v claude)"
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
# 5) Install / Update oosp
# =============================================================================

do_install_oosp() {
    echo -e "\n${BLUE}=== Install / Update oosp ===${NC}"

    local OOSP_START="# OOSP (Object-Oriented Standardized Programming)"
    local OOSP_END="# OOSP END"

    local GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
    local PROJECT_CLAUDE="$(pwd)/CLAUDE.md"

    local CDN_CN="${CDN_BASE}/spec/oosp-cn.md"
    local CDN_EN="${CDN_BASE}/spec/oosp-en.md"

    # ---- Step 1: Remove existing oosp ----
    echo -e "\n${BLUE}[Step 1/3] Scanning for existing oosp content...${NC}"

    local cleaned
    for file in "$GLOBAL_CLAUDE" "$PROJECT_CLAUDE"; do
        if [ ! -f "$file" ]; then
            continue
        fi
        cleaned=false

        if grep -qF "$OOSP_START" "$file" 2>/dev/null; then
            sed_inplace "/$OOSP_START/,/$OOSP_END/d" "$file"
            cleaned=true
        fi

        if [ "$cleaned" = true ]; then
            echo -e "  ${GREEN}✓${NC} Removed oosp from ${file/#$HOME/~}"
        else
            echo -e "  ${YELLOW}[Skip]${NC} No oosp content found in ${file/#$HOME/~}"
        fi
    done

    # ---- Step 2: Ask user where to write ----
    echo -e "\n${BLUE}[Step 2/3] Choose target location...${NC}"
    echo -e "${CYAN}Write oosp to:${NC}"
    echo -e "  ${GREEN}1)${NC} User level    (~/.claude/CLAUDE.md)"
    echo -e "  ${GREEN}2)${NC} Project level (${PROJECT_CLAUDE/#$HOME/~})"
    echo -e "  ${RED}0)${NC} Cancel"
    echo ""
    tty_read LOC_CHOICE "Enter option (0/1/2): "

    local TARGET_FILE=""
    case "$LOC_CHOICE" in
        1) TARGET_FILE="$GLOBAL_CLAUDE" ;;
        2) TARGET_FILE="$PROJECT_CLAUDE" ;;
        0|"")
            echo -e "${YELLOW}Cancelled.${NC}"
            return
            ;;
        *)
            echo -e "${RED}[Error] Invalid option: $LOC_CHOICE${NC}"
            return 1
            ;;
    esac

    # ---- Step 3: Choose language and fetch ----
    echo -e "\n${BLUE}[Step 3/3] Choose language and install...${NC}"
    echo -e "${CYAN}Language:${NC}"
    echo -e "  ${GREEN}1)${NC} 中文 (oosp-cn.md)"
    echo -e "  ${GREEN}2)${NC} English (oosp-en.md)"
    echo -e "  ${RED}0)${NC} Cancel"
    echo ""
    tty_read LANG_CHOICE "Enter option (0/1/2): "

    local CDN_URL=""
    case "$LANG_CHOICE" in
        1) CDN_URL="$CDN_CN" ;;
        2) CDN_URL="$CDN_EN" ;;
        0|"")
            echo -e "${YELLOW}Cancelled.${NC}"
            return
            ;;
        *)
            echo -e "${RED}[Error] Invalid option: $LANG_CHOICE${NC}"
            return 1
            ;;
    esac

    echo -e "${BLUE}Fetching oosp content from CDN...${NC}"
    local oosp_content
    oosp_content=$(curl -fsSL "$CDN_URL" 2>/dev/null)
    if [ -z "$oosp_content" ]; then
        echo -e "${RED}[Error] Failed to fetch oosp content from CDN.${NC}"
        return 1
    fi

    mkdir -p "$(dirname "$TARGET_FILE")"
    touch "$TARGET_FILE"

    if [ -s "$TARGET_FILE" ]; then
        printf '\n%s\n%s\n' "$oosp_content" "$OOSP_END" >> "$TARGET_FILE"
    else
        printf '%s\n%s\n' "$oosp_content" "$OOSP_END" >> "$TARGET_FILE"
    fi

    local display="${TARGET_FILE/#$HOME/~}"
    echo -e "  ${GREEN}✓${NC} oosp written to ${display}"
    echo -e "\n${GREEN}[Success] oosp installed to ${display}!${NC}"
}

# =============================================================================
# CLI parameter handling — direct subcommand execution
# =============================================================================

if [ $# -gt 0 ]; then
    case "$1" in
        install)      do_install ;;
        set-api)      do_set_api ;;
        trust-all)    do_trust_all ;;
        install-oosp) do_install_oosp ;;
        uninstall)    do_uninstall ;;
        *) echo -e "${RED}[Error] Unknown command: $1${NC}"; exit 1 ;;
    esac
    exit 0
fi

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}=== Claude Code Setup v${VERSION} ===${NC}"
echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
echo -e "  ${GREEN}1)${NC} Install / Update Claude Code"
echo -e "  ${GREEN}2)${NC} Set API"
echo -e "  ${GREEN}3)${NC} Trust All Tools"
echo -e "  ${GREEN}4)${NC} Install / Update oosp"
echo -e "  ${RED}5)${NC} Uninstall Claude Code"
echo -e "  ${RED}0)${NC} Exit"
echo ""
stty sane < /dev/tty 2>/dev/null || true
tty_read MENU_CHOICE "Enter option (0-5): "

case "$MENU_CHOICE" in
    1) do_install ;;
    2) do_set_api ;;
    3) do_trust_all ;;
    4) do_install_oosp ;;
    5) do_uninstall ;;
    0|"")
        echo -e "${YELLOW}Exited.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] Invalid option: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
