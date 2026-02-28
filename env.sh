#!/bin/bash

# =============================================================================
# BitsFactor Environment Setup Tool
# Auto-configure development environment: Homebrew, Git, Python3, Node.js, Go.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash env.sh
#   curl -s https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/env.sh | bash
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

# ---- PATH block marker constants ----

NVM_BLOCK_START="# >>> BitsFactor nvm init"
NVM_BLOCK_END="# <<< BitsFactor nvm init"

GO_BLOCK_START="# >>> BitsFactor go SDK PATH"
GO_BLOCK_END="# <<< BitsFactor go SDK PATH"

# ---- Shared functions ----

# has_path_block: check if a PATH block marker already exists in any shell config
# Scans ~/.zshrc, ~/.bashrc, ~/.bash_profile to prevent duplicate writes.
# Uses -F (fixed string) to avoid regex interpretation of marker text.
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
# Adds a leading blank line only when the file is non-empty, to avoid
# writing a spurious blank line at the top of a fresh RC file.
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

# =============================================================================
# 1) Install Homebrew (macOS only)
# =============================================================================

do_install_brew() {
    echo -e "\n${BLUE}=== Install Homebrew ===${NC}"

    if [ "$OS_TYPE" != "macos" ]; then
        echo -e "${YELLOW}[Skip] Homebrew is macOS only.${NC}"
        return 0
    fi

    if command -v brew &> /dev/null; then
        echo -e "${GREEN}[Skip] Homebrew is already installed: $(brew --version | head -1)${NC}"
        return 0
    fi

    echo -e "${BLUE}Installing Homebrew from official installer...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Activate brew in current session.
    # Use [ -x ] to check binary existence before eval to avoid spurious
    # "No such file or directory" stderr on mismatched architectures.
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command -v brew &> /dev/null; then
        echo -e "${GREEN}[Success] Homebrew installed: $(brew --version | head -1)${NC}"
    else
        echo -e "${RED}[Error] Homebrew installation may have failed. Please restart terminal and try again.${NC}"
        return 1
    fi
}

# =============================================================================
# 2) Install Git
# =============================================================================

do_install_git() {
    echo -e "\n${BLUE}=== Install Git ===${NC}"

    if command -v git &> /dev/null; then
        echo -e "${GREEN}[Skip] Git is already installed: $(git --version)${NC}"
        return 0
    fi

    echo -e "${BLUE}Installing Git...${NC}"

    if [ "$OS_TYPE" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}[Error] Homebrew is required to install Git on macOS.${NC}"
            echo -e "${YELLOW}Please install Homebrew first (run this script and select 'Install Homebrew').${NC}"
            return 1
        fi
        brew install git || return 1
    else
        if ! command -v apt-get &> /dev/null; then
            echo -e "${RED}[Error] apt-get not found. Only Debian/Ubuntu Linux is supported.${NC}"
            return 1
        fi
        # Use sudo only when not already running as root
        local SUDO=""
        [ "$(id -u)" -ne 0 ] && SUDO="sudo"
        $SUDO apt-get update -qq          || return 1
        $SUDO apt-get install -y git      || return 1
    fi

    echo -e "${GREEN}[Success] $(git --version)${NC}"
}

# =============================================================================
# 3) Install Python3
# =============================================================================

do_install_python() {
    echo -e "\n${BLUE}=== Install Python3 ===${NC}"

    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}[Skip] Python3 is already installed: $(python3 --version)${NC}"
        # On Linux, also ensure python3-venv is installed
        if [ "$OS_TYPE" = "linux" ] && ! python3 -c "import ensurepip" &>/dev/null; then
            echo -e "${BLUE}Installing python3-venv...${NC}"
            if ! command -v apt-get &> /dev/null; then
                echo -e "${RED}[Error] apt-get not found. Cannot install python3-venv.${NC}"
                return 1
            fi
            local SUDO=""
            [ "$(id -u)" -ne 0 ] && SUDO="sudo"
            $SUDO apt-get update -qq                    || return 1
            $SUDO apt-get install -y python3-venv       || return 1
            echo -e "${GREEN}[Success] python3-venv installed${NC}"
        fi
        return 0
    fi

    echo -e "${BLUE}Installing Python3...${NC}"

    if [ "$OS_TYPE" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}[Error] Homebrew is required to install Python3 on macOS.${NC}"
            echo -e "${YELLOW}Please install Homebrew first (run this script and select 'Install Homebrew').${NC}"
            return 1
        fi
        brew install python3 || return 1
    else
        if ! command -v apt-get &> /dev/null; then
            echo -e "${RED}[Error] apt-get not found. Only Debian/Ubuntu Linux is supported.${NC}"
            return 1
        fi
        local SUDO=""
        [ "$(id -u)" -ne 0 ] && SUDO="sudo"
        $SUDO apt-get update -qq                                    || return 1
        $SUDO apt-get install -y python3 python3-pip python3-venv   || return 1
    fi

    echo -e "${GREEN}[Success] $(python3 --version)${NC}"
}

# =============================================================================
# 4) Install Node.js & npm
# =============================================================================

do_install_node() {
    echo -e "\n${BLUE}=== Install Node.js & npm ===${NC}"

    if command -v node &> /dev/null; then
        echo -e "${GREEN}[Skip] Node.js is already installed: $(node --version)${NC}"
        return 0
    fi

    echo -e "${BLUE}Installing Node.js...${NC}"

    if [ "$OS_TYPE" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}[Error] Homebrew is required to install Node.js on macOS.${NC}"
            echo -e "${YELLOW}Please install Homebrew first (run this script and select 'Install Homebrew').${NC}"
            return 1
        fi
        brew install node || return 1
    else
        # Linux: install via nvm; use NVM_DIR (standard nvm variable) throughout
        export NVM_DIR="$HOME/.nvm"

        if [ ! -f "$NVM_DIR/nvm.sh" ]; then
            echo -e "${BLUE}Downloading nvm v0.39.7...${NC}"
            local tmp_nvm
            tmp_nvm=$(mktemp)
            if ! curl -fsSL "https://fastly.jsdelivr.net/gh/nvm-sh/nvm@v0.39.7/install.sh" -o "$tmp_nvm"; then
                echo -e "${RED}[Error] Failed to download nvm installer.${NC}"
                rm -f "$tmp_nvm"
                return 1
            fi
            # Run installer; clean up temp file regardless of outcome
            bash "$tmp_nvm" || { rm -f "$tmp_nvm"; echo -e "${RED}[Error] nvm installer failed.${NC}"; return 1; }
            rm -f "$tmp_nvm"
        else
            echo -e "${YELLOW}[Skip] nvm already downloaded at ${NVM_DIR}${NC}"
        fi

        # Activate nvm in current session
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

        echo -e "${BLUE}Installing Node.js LTS...${NC}"
        nvm install --lts || return 1
        nvm use --lts     || return 1

        # Write nvm init block only if no NVM_DIR line exists yet in shell RC
        if ! grep -qF 'NVM_DIR' "$SHELL_RC" 2>/dev/null; then
            local nvm_content
            nvm_content='export NVM_DIR="$HOME/.nvm"'
            nvm_content="${nvm_content}"$'\n''[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
            nvm_content="${nvm_content}"$'\n''[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'
            write_path_block "$NVM_BLOCK_START" "$NVM_BLOCK_END" "$nvm_content"
        else
            echo -e "  ${YELLOW}[Skip]${NC} nvm init already present in ${SHELL_RC/#$HOME/~}"
        fi
    fi

    echo -e "${GREEN}[Success] Node.js $(node --version), npm $(npm --version)${NC}"
}

# =============================================================================
# 5) Install Go SDK
# =============================================================================

do_install_go() {
    echo -e "\n${BLUE}=== Install Go ===${NC}"

    if command -v go &> /dev/null; then
        echo -e "${GREEN}[Skip] Go is already installed: $(go version)${NC}"
        return 0
    fi

    echo -e "${BLUE}Installing Go...${NC}"

    if [ "$OS_TYPE" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}[Error] Homebrew is required to install Go on macOS.${NC}"
            echo -e "${YELLOW}Please install Homebrew first (run this script and select 'Install Homebrew').${NC}"
            return 1
        fi
        brew install go || return 1
    else
        # Linux: install to $HOME/.go_sdk (no sudo needed)
        local GO_INSTALL_DIR="$HOME/.go_sdk"
        # 动态获取最新 Go 版本，失败时降级为固定版本
        local GO_VERSION
        GO_VERSION=$(curl -fsSL --max-time 5 "https://go.dev/VERSION?m=text" 2>/dev/null | head -1 | sed 's/^go//')
        if [ -z "$GO_VERSION" ]; then
            GO_VERSION="1.23.5"
            echo -e "  ${YELLOW}[Warning] Could not fetch latest Go version, using fallback: ${GO_VERSION}${NC}"
        fi

        # Detect CPU architecture
        local ARCH
        case "$(uname -m)" in
            x86_64)  ARCH="amd64" ;;
            aarch64) ARCH="arm64" ;;
            armv7l)  ARCH="armv6l" ;;
            *)
                echo -e "${RED}[Error] Unsupported architecture: $(uname -m)${NC}"
                return 1
                ;;
        esac

        local GO_TAR="go${GO_VERSION}.linux-${ARCH}.tar.gz"
        local GO_URL="https://dl.google.com/go/${GO_TAR}"

        echo -e "${BLUE}Downloading Go ${GO_VERSION} (${ARCH})...${NC}"
        local tmp_go
        tmp_go=$(mktemp)
        if ! curl -fsSL "$GO_URL" -o "$tmp_go"; then
            echo -e "${RED}[Error] Failed to download Go ${GO_VERSION}.${NC}"
            rm -f "$tmp_go"
            return 1
        fi

        # Extract to a temp dir on the same filesystem as $HOME to enable
        # atomic mv (avoids cross-device copy when /tmp is a separate partition).
        echo -e "${BLUE}Extracting Go ${GO_VERSION}...${NC}"
        local tmp_dir
        tmp_dir=$(TMPDIR="$HOME" mktemp -d)
        if ! tar -xzf "$tmp_go" -C "$tmp_dir" --strip-components=1; then
            echo -e "${RED}[Error] Failed to extract Go archive. Existing installation preserved.${NC}"
            rm -f "$tmp_go"
            rm -rf "$tmp_dir"
            return 1
        fi
        rm -f "$tmp_go"

        # Extraction succeeded — atomically replace the old install
        rm -rf "$GO_INSTALL_DIR"
        mv "$tmp_dir" "$GO_INSTALL_DIR"
        echo -e "  ${GREEN}✓${NC} Installed to ${GO_INSTALL_DIR}"

        # Write PATH block
        local go_content
        go_content='export GOROOT="$HOME/.go_sdk"'
        go_content="${go_content}"$'\n''export PATH="$GOROOT/bin:$PATH"'
        write_path_block "$GO_BLOCK_START" "$GO_BLOCK_END" "$go_content"

        # Activate in current session
        export GOROOT="$HOME/.go_sdk"
        export PATH="$GOROOT/bin:$PATH"
    fi

    echo -e "${GREEN}[Success] $(go version)${NC}"
}

# =============================================================================
# Install All
# =============================================================================

do_install_all() {
    echo -e "\n${BLUE}=== Install All ===${NC}"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "${CYAN}Installing: Brew + Git + Python3 + Node.js + Go${NC}\n"
    else
        echo -e "${CYAN}Installing: Git + Python3 + Node.js + Go${NC}\n"
    fi

    # Track per-step result (0 = ok, 1 = failed) for the summary.
    # Each function uses explicit || return 1 on critical commands so that
    # failures are reported accurately on both bash 3.x and bash 5.x,
    # regardless of whether set -e is inherited in the || call context.
    local brew_rc=0 git_rc=0 python_rc=0 node_rc=0 go_rc=0
    do_install_brew   || brew_rc=1
    do_install_git    || git_rc=1
    do_install_python || python_rc=1
    do_install_node   || node_rc=1
    do_install_go     || go_rc=1

    local SHELL_RC_DISPLAY="${SHELL_RC/#$HOME/~}"

    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}  Summary${NC}"
    echo -e "${CYAN}========================================${NC}"
    # Homebrew is macOS-only; omit from summary on Linux to avoid confusion
    if [ "$OS_TYPE" = "macos" ]; then
        [ "$brew_rc"    -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Homebrew"    || echo -e "  ${RED}✗${NC}  Homebrew"
    fi
    [ "$git_rc"     -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Git"          || echo -e "  ${RED}✗${NC}  Git"
    [ "$python_rc"  -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Python3"      || echo -e "  ${RED}✗${NC}  Python3"
    [ "$node_rc"    -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Node.js"      || echo -e "  ${RED}✗${NC}  Node.js"
    [ "$go_rc"      -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Go"           || echo -e "  ${RED}✗${NC}  Go"
    echo -e "${CYAN}========================================${NC}"

    echo -e "\n${YELLOW}[Reminder] To apply PATH changes in your current terminal:${NC}"
    echo -e "  ${CYAN}source ${SHELL_RC_DISPLAY}${NC}"
}

# =============================================================================
# 7) Install / Update OOSP
# =============================================================================

do_install_oosp() {
    echo -e "\n${BLUE}=== Install / Update OOSP ===${NC}"

    local OOSP_CN_START="# >>> BitsFactor OOSP CN"
    local OOSP_CN_END="# <<< BitsFactor OOSP CN"
    local OOSP_EN_START="# >>> BitsFactor OOSP EN"
    local OOSP_EN_END="# <<< BitsFactor OOSP EN"

    local GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
    local PROJECT_CLAUDE="$(pwd)/CLAUDE.md"

    local CDN_CN="https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/spec/oosp-cn.md"
    local CDN_EN="https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/spec/oosp-en.md"

    # _sed_inplace: cross-platform sed -i wrapper
    _sed_inplace() {
        if [ "$OS_TYPE" = "macos" ]; then
            sed -i '' "$1" "$2"
        else
            sed -i "$1" "$2"
        fi
    }

    # ---- Step 1: Remove existing OOSP (CN and EN, markers and old format) ----
    echo -e "\n${BLUE}[Step 1/3] Scanning for existing OOSP content...${NC}"

    local cleaned
    for file in "$GLOBAL_CLAUDE" "$PROJECT_CLAUDE"; do
        if [ ! -f "$file" ]; then
            continue
        fi
        cleaned=false

        # New format: marker-based blocks
        if grep -qF "$OOSP_CN_START" "$file" 2>/dev/null; then
            _sed_inplace "/$OOSP_CN_START/,/$OOSP_CN_END/d" "$file"
            cleaned=true
        fi
        if grep -qF "$OOSP_EN_START" "$file" 2>/dev/null; then
            _sed_inplace "/$OOSP_EN_START/,/$OOSP_EN_END/d" "$file"
            cleaned=true
        fi

        # Old format: no markers, detect by OOSP title heading.
        # Delete from the heading line until the next top-level "# " heading (or EOF).
        if grep -qF "# OOSP 规范" "$file" 2>/dev/null || \
           grep -qF "# OOSP Specification" "$file" 2>/dev/null; then
            local tmp
            tmp=$(mktemp)
            awk '
                /^# OOSP 规范/ || /^# OOSP Specification/ { in_oosp = 1; next }
                in_oosp && /^# /                           { in_oosp = 0 }
                !in_oosp                                   { print }
            ' "$file" > "$tmp"
            mv "$tmp" "$file"
            cleaned=true
        fi

        if [ "$cleaned" = true ]; then
            echo -e "  ${GREEN}✓${NC} Removed OOSP from ${file/#$HOME/~}"
        else
            echo -e "  ${YELLOW}[Skip]${NC} No OOSP content found in ${file/#$HOME/~}"
        fi
    done

    # ---- Step 2: Ask user where to write ----
    echo -e "\n${BLUE}[Step 2/3] Choose target location...${NC}"
    echo -e "${CYAN}Write OOSP to:${NC}"
    echo -e "  ${GREEN}1)${NC} User level    (~/.claude/CLAUDE.md)"
    echo -e "  ${GREEN}2)${NC} Project level (${PROJECT_CLAUDE/#$HOME/~})"
    echo -e "  ${RED}0)${NC} Cancel"
    echo ""
    read -p "Enter option (0/1/2): " LOC_CHOICE < /dev/tty

    local TARGET_FILE=""
    case "$LOC_CHOICE" in
        1) TARGET_FILE="$GLOBAL_CLAUDE" ;;
        2) TARGET_FILE="$PROJECT_CLAUDE" ;;
        0|"")
            echo -e "${YELLOW}Cancelled.${NC}"
            unset -f _sed_inplace
            return
            ;;
        *)
            echo -e "${RED}[Error] Invalid option: $LOC_CHOICE${NC}"
            unset -f _sed_inplace
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
    read -p "Enter option (0/1/2): " LANG_CHOICE < /dev/tty

    local CDN_URL="" BLOCK_START="" BLOCK_END=""
    case "$LANG_CHOICE" in
        1) CDN_URL="$CDN_CN"; BLOCK_START="$OOSP_CN_START"; BLOCK_END="$OOSP_CN_END" ;;
        2) CDN_URL="$CDN_EN"; BLOCK_START="$OOSP_EN_START"; BLOCK_END="$OOSP_EN_END" ;;
        0|"")
            echo -e "${YELLOW}Cancelled.${NC}"
            unset -f _sed_inplace
            return
            ;;
        *)
            echo -e "${RED}[Error] Invalid option: $LANG_CHOICE${NC}"
            unset -f _sed_inplace
            return 1
            ;;
    esac

    echo -e "${BLUE}Fetching OOSP content from CDN...${NC}"
    local oosp_content
    oosp_content=$(curl -fsSL "$CDN_URL" 2>/dev/null)
    if [ -z "$oosp_content" ]; then
        echo -e "${RED}[Error] Failed to fetch OOSP content from CDN.${NC}"
        unset -f _sed_inplace
        return 1
    fi

    mkdir -p "$(dirname "$TARGET_FILE")"
    touch "$TARGET_FILE"

    if [ -s "$TARGET_FILE" ]; then
        printf '\n%s\n%s\n%s\n' "$BLOCK_START" "$oosp_content" "$BLOCK_END" >> "$TARGET_FILE"
    else
        printf '%s\n%s\n%s\n' "$BLOCK_START" "$oosp_content" "$BLOCK_END" >> "$TARGET_FILE"
    fi

    local display="${TARGET_FILE/#$HOME/~}"
    echo -e "  ${GREEN}✓${NC} OOSP written to ${display}"
    echo -e "\n${GREEN}[Success] OOSP installed to ${display}!${NC}"

    unset -f _sed_inplace
}

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}======== BitsFactor Environment Setup v${VERSION} ========${NC}"
echo -e "Detected OS:   ${CYAN}${OS_TYPE}${NC}"
echo -e "Shell config:  ${CYAN}${SHELL_RC/#$HOME/~}${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
if [ "$OS_TYPE" = "macos" ]; then
    echo -e "  ${GREEN}1)${NC} Install All  (Brew + Git + Python3 + Node.js + Go)"
else
    echo -e "  ${GREEN}1)${NC} Install All  (Git + Python3 + Node.js + Go)"
fi
echo -e "  ${GREEN}2)${NC} Install Homebrew  ${YELLOW}[macOS only]${NC}"
echo -e "  ${GREEN}3)${NC} Install Git"
echo -e "  ${GREEN}4)${NC} Install Python3"
echo -e "  ${GREEN}5)${NC} Install Node.js & npm"
echo -e "  ${GREEN}6)${NC} Install Go"
echo -e "  ${GREEN}7)${NC} Install / Update OOSP"
echo -e "  ${RED}0)${NC} Exit"
echo ""
read -p "Enter option (0-7): " MENU_CHOICE < /dev/tty

case "$MENU_CHOICE" in
    1) do_install_all ;;
    2) do_install_brew ;;
    3) do_install_git ;;
    4) do_install_python ;;
    5) do_install_node ;;
    6) do_install_go ;;
    7) do_install_oosp ;;
    0|"")
        echo -e "${YELLOW}Exited.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] Invalid option: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
