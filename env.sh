#!/bin/bash

# =============================================================================
# BitsFactor Environment Setup Tool
# Auto-configure development environment: Homebrew, Git, Python3, Node.js, Go, Docker.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash env.sh
# Optional:
#   BFS_TIMEZONE=UTC bash env.sh
# =============================================================================

set -e

# Load version: BFS_VER env var (remote) > local version.sh (development)
_SCRIPT_DIR=""
[ -n "${BASH_SOURCE[0]}" ] && _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd 2>/dev/null)"
[ -n "$_SCRIPT_DIR" ] && [ -f "$_SCRIPT_DIR/version.sh" ] && . "$_SCRIPT_DIR/version.sh"
[ -n "$BFS_VER" ] && VERSION="$BFS_VER"

: "${CDN_BASE:=https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v${VERSION}}"
: "${BFS_TIMEZONE:=Asia/Shanghai}"

# Color definitions
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

# TTY overrides used by the local test harness
: "${BFS_TTY_OUT:=/dev/tty}"
[ -n "${BFS_TTY_INPUT_FILE:-}" ] && exec 9< "$BFS_TTY_INPUT_FILE"

# ---- OS detection ----

OS_TYPE=""
UNAME_S="$(uname -s)"
case "$UNAME_S" in
    MINGW*|MSYS*|CYGWIN*)
        echo -e "${RED}[Error] Native Windows shells are not supported.${NC}"
        echo -e "${YELLOW}Please run this script inside WSL2 Ubuntu on Windows, or use macOS/Linux.${NC}"
        exit 1
        ;;
    Darwin*)  OS_TYPE="macos" ;;
    Linux*)   OS_TYPE="linux" ;;
    *)
        echo -e "${RED}[Error] Unsupported OS: ${UNAME_S}${NC}"
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

# ---- PATH block marker constants ----

NVM_BLOCK_START="# >>> BitsFactor nvm init"
NVM_BLOCK_END="# <<< BitsFactor nvm init"

GO_BLOCK_START="# >>> BitsFactor go SDK PATH"
GO_BLOCK_END="# <<< BitsFactor go SDK PATH"

BREW_BLOCK_START="# >>> BitsFactor brew shellenv"
BREW_BLOCK_END="# <<< BitsFactor brew shellenv"

# ---- Shared functions ----

# tty_read: read one line from /dev/tty
# Args: $1 = variable name to store result
#       $2 = (optional) prompt string (written directly to /dev/tty)
tty_read() {
    if [ -n "$2" ]; then
        printf '%s' "$2" > "$BFS_TTY_OUT" 2>/dev/null || printf '%s' "$2" >&2
    fi
    if [ -n "${BFS_TTY_INPUT_FILE:-}" ]; then
        IFS= read -r "$1" <&9 || true
    else
        IFS= read -r "$1" < /dev/tty || true
    fi
}

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

# sed_inplace: cross-platform sed -i wrapper
# Args: $1 = sed expression, $2 = file path
sed_inplace() {
    if [ "$OS_TYPE" = "macos" ]; then
        sed -i '' "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

# sshd_set_port_in_file: update or append a Port directive in a config file
# Args: $1 = sshd_config path, $2 = new port, $3 = optional sudo command
sshd_set_port_in_file() {
    local sshd_config="$1"
    local new_port="$2"
    local sudo_cmd="${3:-}"
    local sed_expr="s/^[[:space:]]*#\\{0,1\\}[[:space:]]*Port[[:space:]].*/Port ${new_port}/"

    if grep -qE '^[[:space:]]*#?[[:space:]]*Port[[:space:]]+' "$sshd_config"; then
        if [ -n "$sudo_cmd" ]; then
            $sudo_cmd sh -c "sed -i.bak '$sed_expr' '$sshd_config' && rm -f '${sshd_config}.bak'"
        else
            sed_inplace "$sed_expr" "$sshd_config"
        fi
    else
        printf 'Port %s\n' "$new_port" | $sudo_cmd tee -a "$sshd_config" > /dev/null
    fi
}

# sshd_has_seen_config: track recursive Include traversal safely
# Args: $1 = config path
sshd_has_seen_config() {
    case "
${SSHD_SEEN_CONFIGS:-}
" in
        *"
$1
"*) return 0 ;;
    esac
    return 1
}

# sshd_strip_quotes: trim one layer of matching shell quotes
# Args: $1 = raw token
sshd_strip_quotes() {
    local value="$1"
    case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    printf '%s\n' "$value"
}

# sshd_resolve_include_pattern: resolve sshd Include paths like sshd(8)
# Relative include paths are always anchored at /etc/ssh.
# Args: $1 = include token
sshd_resolve_include_pattern() {
    local include_pattern="$1"

    include_pattern="$(sshd_strip_quotes "$include_pattern")"
    case "$include_pattern" in
        /*) printf '%s\n' "$include_pattern" ;;
        *)  printf '/etc/ssh/%s\n' "$include_pattern" ;;
    esac
}

# sshd_list_config_files: print sshd_config and recursively included files
# Args: $1 = sshd_config path
sshd_list_config_files() {
    local sshd_config="$1"
    local line=""
    local include_args=""
    local include_pattern=""
    local resolved_pattern=""
    local include_matches=()
    local include_file=""

    [ -f "$sshd_config" ] || return 0
    if sshd_has_seen_config "$sshd_config"; then
        return 0
    fi
    SSHD_SEEN_CONFIGS="${SSHD_SEEN_CONFIGS:-}
$sshd_config"

    printf '%s\n' "$sshd_config"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        [[ "$line" =~ [^[:space:]] ]] || continue
        [[ "$line" =~ ^[[:space:]]*Match[[:space:]]+ ]] && break
        [[ "$line" =~ ^[[:space:]]*Include[[:space:]]+ ]] || continue

        include_args="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*Include[[:space:]]+//')"
        read -r -a include_matches <<< "$include_args"
        for include_pattern in "${include_matches[@]}"; do
            resolved_pattern="$(sshd_resolve_include_pattern "$include_pattern")"
            shopt -s nullglob
            include_matches=( $resolved_pattern )
            shopt -u nullglob
            for include_file in "${include_matches[@]}"; do
                sshd_list_config_files "$include_file"
            done
        done
    done < "$sshd_config"
}

# sshd_get_configured_ports_fallback: parse explicit Port directives without sshd
# Args: $1 = sshd_config path
sshd_get_configured_ports_fallback() {
    local sshd_config="$1"
    local file=""
    local line=""

    SSHD_SEEN_CONFIGS=""
    while IFS= read -r file; do
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%%#*}"
            [[ "$line" =~ [^[:space:]] ]] || continue
            [[ "$line" =~ ^[[:space:]]*Match[[:space:]]+ ]] && break
            if [[ "$line" =~ ^[[:space:]]*Port[[:space:]]+([0-9]+)([[:space:]]+.*)?$ ]]; then
                printf '%s\n' "${BASH_REMATCH[1]}"
            fi
        done < "$file"
    done < <(sshd_list_config_files "$sshd_config")
}

# sshd_get_configured_ports: list all configured SSH ports after Include expansion
# Args: $1 = sshd_config path
sshd_get_configured_ports() {
    local sshd_config="$1"

    if command -v sshd &> /dev/null; then
        sshd -T -f "$sshd_config" 2>/dev/null | awk '/^port / { print $2 }' | awk '!seen[$0]++'
    else
        sshd_get_configured_ports_fallback "$sshd_config" | awk '!seen[$0]++'
    fi
}

# sshd_remove_legacy_port_dropin: remove the old BitsFactor Port drop-in if present
# Args: $1 = sshd_config path, $2 = optional sudo command
sshd_remove_legacy_port_dropin() {
    local sshd_config="$1"
    local sudo_cmd="${2:-}"
    local file=""

    SSHD_SEEN_CONFIGS=""
    while IFS= read -r file; do
        [ "$(basename "$file")" = "0-bitsfactor-port.conf" ] || continue
        if [ -n "$sudo_cmd" ]; then
            $sudo_cmd rm -f "$file" || return 1
        else
            rm -f "$file" || return 1
        fi
        echo -e "${CYAN}Removed legacy SSH drop-in: ${file}${NC}"
    done < <(sshd_list_config_files "$sshd_config")
}

# sshd_replace_port_22_directives: update explicit Port 22 lines across config files
# Args: $1 = sshd_config path, $2 = new port, $3 = optional sudo command
sshd_replace_port_22_directives() {
    local sshd_config="$1"
    local new_port="$2"
    local sudo_cmd="${3:-}"
    local file=""
    local changed=1
    local sed_expr="s/^[[:space:]]*Port[[:space:]]\\+22\\([[:space:]]*#.*\\)\\{0,1\\}[[:space:]]*$/Port ${new_port}/"

    SSHD_SEEN_CONFIGS=""
    while IFS= read -r file; do
        if ! grep -qE '^[[:space:]]*Port[[:space:]]+22([[:space:]]*#.*)?[[:space:]]*$' "$file"; then
            continue
        fi
        if [ -n "$sudo_cmd" ]; then
            $sudo_cmd sh -c "sed -i.bak '$sed_expr' '$file' && rm -f '${file}.bak'" || return 1
        else
            sed_inplace "$sed_expr" "$file" || return 1
        fi
        changed=0
    done < <(sshd_list_config_files "$sshd_config")

    return "$changed"
}

# join_lines_csv: join newline-delimited values with ", "
join_lines_csv() {
    awk 'NF { if (seen++) printf ", "; printf "%s", $0 } END { if (seen) printf "\n" }'
}

# sshd_validate_config: syntax-check an sshd config when sshd is available
# Args: $1 = sshd_config path, $2 = optional sudo command
sshd_validate_config() {
    local sshd_config="$1"
    local sudo_cmd="${2:-}"

    if ! command -v sshd &> /dev/null; then
        return 0
    fi

    if [ -n "$sudo_cmd" ]; then
        $sudo_cmd sshd -t -f "$sshd_config" > /dev/null 2>&1
    else
        sshd -t -f "$sshd_config" > /dev/null 2>&1
    fi
}

# restart_sshd_service: reload/restart SSH service across init systems
# Args: $1 = optional sudo command
restart_sshd_service() {
    local sudo_cmd="${1:-}"
    local action unit init_script

    for action in reload restart; do
        if command -v systemctl &> /dev/null; then
            for unit in sshd ssh; do
                if $sudo_cmd systemctl "$action" "$unit" > /dev/null 2>&1; then
                    return 0
                fi
            done
        fi

        if command -v service &> /dev/null; then
            for unit in sshd ssh; do
                if $sudo_cmd service "$unit" "$action" > /dev/null 2>&1; then
                    return 0
                fi
            done
        fi

        if command -v rc-service &> /dev/null; then
            for unit in sshd ssh; do
                if $sudo_cmd rc-service "$unit" "$action" > /dev/null 2>&1; then
                    return 0
                fi
            done
        fi

        for init_script in /etc/init.d/sshd /etc/init.d/ssh; do
            if [ -x "$init_script" ] && $sudo_cmd "$init_script" "$action" > /dev/null 2>&1; then
                return 0
            fi
        done
    done

    return 1
}

# =============================================================================
# 1) Set System Timezone
# =============================================================================

do_set_timezone() {
    echo -e "\n${BLUE}=== Set System Timezone ===${NC}"

    local target_tz="${1:-$BFS_TIMEZONE}"
    local current_tz=""
    local SUDO=""
    [ "$(id -u)" -ne 0 ] && SUDO="sudo"

    if [ -z "$target_tz" ]; then
        echo -e "${RED}[Error] Timezone cannot be empty.${NC}"
        return 1
    fi

    case "$OS_TYPE" in
        linux)
            if [ ! -e "/usr/share/zoneinfo/$target_tz" ]; then
                echo -e "${RED}[Error] Timezone not found: ${target_tz}${NC}"
                return 1
            fi

            if command -v timedatectl &> /dev/null; then
                current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || true)
            elif [ -L /etc/localtime ]; then
                current_tz=$(readlink /etc/localtime 2>/dev/null | sed 's#^.*zoneinfo/##')
            elif [ -f /etc/timezone ]; then
                current_tz=$(cat /etc/timezone 2>/dev/null)
            fi

            if [ "$current_tz" = "$target_tz" ]; then
                echo -e "${GREEN}[Skip] System timezone is already ${target_tz}.${NC}"
                return 0
            fi

            echo -e "${BLUE}Setting Linux timezone to ${target_tz}...${NC}"
            if command -v timedatectl &> /dev/null; then
                if ! $SUDO timedatectl set-timezone "$target_tz"; then
                    echo -e "  ${YELLOW}[Warning]${NC} timedatectl is unavailable, falling back to /etc/localtime"
                    $SUDO ln -snf "/usr/share/zoneinfo/$target_tz" /etc/localtime || return 1
                    if [ -e /etc/timezone ] || [ -d /etc ]; then
                        printf '%s\n' "$target_tz" | $SUDO tee /etc/timezone > /dev/null || return 1
                    fi
                fi
            else
                $SUDO ln -snf "/usr/share/zoneinfo/$target_tz" /etc/localtime || return 1
                if [ -e /etc/timezone ] || [ -d /etc ]; then
                    printf '%s\n' "$target_tz" | $SUDO tee /etc/timezone > /dev/null || return 1
                fi
            fi
            ;;
        macos)
            if ! command -v systemsetup &> /dev/null; then
                echo -e "${RED}[Error] systemsetup not found. Cannot set macOS timezone.${NC}"
                return 1
            fi

            current_tz=$(systemsetup -gettimezone 2>/dev/null | sed 's/^Time Zone: //')
            if [ "$current_tz" = "$target_tz" ]; then
                echo -e "${GREEN}[Skip] System timezone is already ${target_tz}.${NC}"
                return 0
            fi

            echo -e "${BLUE}Setting macOS timezone to ${target_tz}...${NC}"
            $SUDO systemsetup -settimezone "$target_tz" > /dev/null || return 1
            ;;
        *)
            echo -e "${RED}[Error] Unsupported OS for timezone setup: ${OS_TYPE}${NC}"
            return 1
            ;;
    esac

    echo -e "${GREEN}[Success] System timezone set to ${target_tz}${NC}"
}

# =============================================================================
# 2) Install Homebrew (macOS only)
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

    # Ensure Xcode Command Line Tools are installed (Homebrew dependency).
    # In pipe / SSH mode the macOS GUI installer dialog cannot be interacted
    # with, so we trigger `xcode-select --install` beforehand and wait.
    if ! xcode-select -p &>/dev/null; then
        echo -e "${BLUE}Installing Xcode Command Line Tools (required by Homebrew)...${NC}"
        xcode-select --install 2>/dev/null || true
        # Wait up to 10 minutes for the CLT installation to finish
        local waited=0
        while ! xcode-select -p &>/dev/null; do
            if [ "$waited" -ge 600 ]; then
                echo -e "${RED}[Error] Timed out waiting for Xcode CLT installation.${NC}"
                echo -e "${YELLOW}Please install manually: xcode-select --install${NC}"
                return 1
            fi
            sleep 5
            waited=$((waited + 5))
        done
        echo -e "${GREEN}[Success] Xcode Command Line Tools installed.${NC}"
    fi

    echo -e "${BLUE}Installing Homebrew from official installer...${NC}"
    # NONINTERACTIVE=1: skip the "Press RETURN" confirmation prompt,
    # which hangs in curl|bash pipe mode where stdin is unavailable.
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1

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

        # Persist brew shellenv to shell RC so brew is available in new terminals
        local brew_content
        brew_content="eval \"\$($(command -v brew) shellenv)\""
        write_path_block "$BREW_BLOCK_START" "$BREW_BLOCK_END" "$brew_content"
    else
        echo -e "${RED}[Error] Homebrew installation may have failed. Please restart terminal and try again.${NC}"
        return 1
    fi
}

# =============================================================================
# 3) Install Git
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
# 4) Install Python3
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
# 5) Install Node.js & npm
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

        # Write nvm init block only if our managed block is not already present
        if ! has_path_block "$NVM_BLOCK_START"; then
            local nvm_content
            nvm_content='export NVM_DIR="$HOME/.nvm"'
            nvm_content="${nvm_content}"$'\n''[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
            nvm_content="${nvm_content}"$'\n''[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'
            write_path_block "$NVM_BLOCK_START" "$NVM_BLOCK_END" "$nvm_content"
        else
            echo -e "  ${YELLOW}[Skip]${NC} nvm init already present in shell config"
        fi
    fi

    echo -e "${GREEN}[Success] Node.js $(node --version), npm $(npm --version)${NC}"
}

# =============================================================================
# 6) Install Go SDK
# =============================================================================

do_install_go() {
    echo -e "\n${BLUE}=== Install Go ===${NC}"

    # Activate existing Go SDK in current session (PATH block may not be sourced yet)
    if [ -x "$HOME/.go_sdk/bin/go" ]; then
        export GOROOT="$HOME/.go_sdk"
        export PATH="$GOROOT/bin:$PATH"
    fi

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
# 7) Install Docker
# =============================================================================

do_install_docker() {
    echo -e "\n${BLUE}=== Install Docker ===${NC}"

    if command -v docker &> /dev/null; then
        echo -e "${GREEN}[Skip] Docker is already installed: $(docker --version)${NC}"
        return 0
    fi

    echo -e "${BLUE}Installing Docker...${NC}"

    if [ "$OS_TYPE" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}[Error] Homebrew is required to install Docker on macOS.${NC}"
            echo -e "${YELLOW}Please install Homebrew first (run this script and select 'Install Homebrew').${NC}"
            return 1
        fi
        brew install --cask docker || return 1
        open -a Docker
    else
        # Linux: use official convenience script (supports Debian, Ubuntu, etc.)
        local tmp_docker
        tmp_docker=$(mktemp)
        if ! curl -fsSL "https://get.docker.com" -o "$tmp_docker"; then
            echo -e "${RED}[Error] Failed to download Docker installer.${NC}"
            rm -f "$tmp_docker"
            return 1
        fi
        local SUDO=""
        [ "$(id -u)" -ne 0 ] && SUDO="sudo"
        $SUDO sh "$tmp_docker" || { rm -f "$tmp_docker"; echo -e "${RED}[Error] Docker installation failed.${NC}"; return 1; }
        rm -f "$tmp_docker"

        # Add current user to docker group (avoid needing sudo for docker commands)
        if [ "$(id -u)" -ne 0 ]; then
            $SUDO usermod -aG docker "$USER" 2>/dev/null || true
            echo -e "  ${GREEN}✓${NC} Added ${USER} to docker group (re-login to take effect)"
        fi
    fi

    echo -e "${GREEN}[Success] $(docker --version)${NC}"
    # docker compose (v2) is included:
    #   Linux: get.docker.com installs docker-compose-plugin
    #   macOS: Docker Desktop bundles it
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}         $(docker compose version)${NC}"
    fi
}

# =============================================================================
# 8) Change SSH Port (Linux only)
# =============================================================================

do_change_ssh_port() {
    echo -e "\n${BLUE}=== Change SSH Port ===${NC}"

    if [ "$OS_TYPE" != "linux" ]; then
        echo -e "${YELLOW}[Skip] This option is for Linux only.${NC}"
        return 0
    fi

    local SSHD_CONFIG="${BFS_SSHD_CONFIG:-/etc/ssh/sshd_config}"
    if [ ! -f "$SSHD_CONFIG" ]; then
        echo -e "${RED}[Error] ${SSHD_CONFIG} not found.${NC}"
        return 1
    fi

    local SUDO=""
    [ "$(id -u)" -ne 0 ] && SUDO="sudo"

    sshd_remove_legacy_port_dropin "$SSHD_CONFIG" "$SUDO" || return 1

    # Read all configured ports so Include-based layouts and duplicate Port
    # lines are handled correctly.
    local CURRENT_PORTS=""
    local CURRENT_PORTS_DISPLAY=""
    CURRENT_PORTS="$(sshd_get_configured_ports "$SSHD_CONFIG")"
    if [ -n "$CURRENT_PORTS" ]; then
        CURRENT_PORTS_DISPLAY="$(printf '%s\n' "$CURRENT_PORTS" | join_lines_csv)"
    else
        CURRENT_PORTS_DISPLAY="22"
    fi
    echo -e "Current SSH port(s): ${CYAN}${CURRENT_PORTS_DISPLAY}${NC}"

    if [ -n "$CURRENT_PORTS" ] && ! printf '%s\n' "$CURRENT_PORTS" | grep -qx '22'; then
        echo -e "${YELLOW}[Skip] SSH is already using non-default port(s): ${CURRENT_PORTS_DISPLAY}.${NC}"
        return 0
    fi

    if [ -n "$CURRENT_PORTS" ] && printf '%s\n' "$CURRENT_PORTS" | awk '$0 != 22 { found=1 } END { exit found ? 0 : 1 }'; then
        echo -e "${YELLOW}[Info] SSH already has additional non-default port(s); only Port 22 entries will be changed.${NC}"
    fi

    # Ask whether to change the port; use $1 if provided, otherwise prompt interactively
    local NEW_PORT="${1:-}"
    if [ -z "$NEW_PORT" ]; then
        local CHANGE_PORT=""
        echo -e "${CYAN}SSH port is still the default 22.${NC}"
        tty_read CHANGE_PORT "Do you want to change it now? (y/N): "
        case "$CHANGE_PORT" in
            y|Y|yes|YES)
                ;;
            *)
                echo -e "${YELLOW}[Skip] SSH port unchanged.${NC}"
                return 0
                ;;
        esac

        tty_read NEW_PORT "Enter new SSH port [60101]: "
        : "${NEW_PORT:=60101}"
    fi

    # Validate
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1024 ] || [ "$NEW_PORT" -gt 65535 ]; then
        echo -e "${RED}[Error] Invalid port: ${NEW_PORT}. Must be 1024–65535.${NC}"
        return 1
    fi

    if [ -n "$CURRENT_PORTS" ] && printf '%s\n' "$CURRENT_PORTS" | grep -qx "$NEW_PORT" && ! printf '%s\n' "$CURRENT_PORTS" | grep -qx '22'; then
        echo -e "${YELLOW}[Skip] Port ${NEW_PORT} is already configured.${NC}"
        return 0
    fi

    # Update every explicit Port 22 directive across the config graph. If the
    # daemon relies on the implicit default, activate Port in the main file.
    echo -e "${BLUE}Setting SSH port to ${NEW_PORT}...${NC}"
    if ! sshd_replace_port_22_directives "$SSHD_CONFIG" "$NEW_PORT" "$SUDO"; then
        sshd_set_port_in_file "$SSHD_CONFIG" "$NEW_PORT" "$SUDO" || return 1
    fi

    if ! sshd_validate_config "$SSHD_CONFIG" "$SUDO"; then
        echo -e "${RED}[Error] sshd config validation failed. Please inspect ${SSHD_CONFIG}.${NC}"
        return 1
    fi

    local CONFIGURED_PORTS=""
    CONFIGURED_PORTS="$(sshd_get_configured_ports "$SSHD_CONFIG")"
    if printf '%s\n' "$CONFIGURED_PORTS" | grep -qx '22'; then
        echo -e "${RED}[Error] SSH still has Port 22 configured. Please inspect Include files manually.${NC}"
        return 1
    fi
    if ! printf '%s\n' "$CONFIGURED_PORTS" | grep -qx "$NEW_PORT"; then
        echo -e "${RED}[Error] SSH port ${NEW_PORT} was not found after updating config.${NC}"
        return 1
    fi

    # Restart sshd
    echo -e "${BLUE}Restarting sshd...${NC}"
    if restart_sshd_service "$SUDO"; then
        echo -e "${GREEN}[Success] SSH port changed to ${NEW_PORT}.${NC}"
    else
        echo -e "${RED}[Error] Failed to restart sshd. Please restart manually.${NC}"
        return 1
    fi

    echo -e "\n${YELLOW}[Important] Before closing this session:${NC}"
    echo -e "  1. Ensure firewall allows port ${NEW_PORT}"
    echo -e "  2. Test new connection: ${CYAN}ssh -p ${NEW_PORT} user@host${NC}"
}

# =============================================================================
# Install All
# =============================================================================

do_install_all() {
    echo -e "\n${BLUE}=== Install All ===${NC}"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "${CYAN}Installing: Timezone + Brew + Git + Python3 + Node.js + Go + Docker${NC}\n"
    else
        echo -e "${CYAN}Installing: Timezone + Git + Python3 + Node.js + Go + Docker${NC}"
        echo -e "${CYAN}After that, you can choose whether to change the SSH port if it is still 22.${NC}\n"
    fi

    # Track per-step result (0 = ok, 1 = failed) for the summary.
    # Each function uses explicit || return 1 on critical commands so that
    # failures are reported accurately on both bash 3.x and bash 5.x,
    # regardless of whether set -e is inherited in the || call context.
    local timezone_rc=0 brew_rc=0 git_rc=0 python_rc=0 node_rc=0 go_rc=0 docker_rc=0 ssh_rc=0
    do_set_timezone   || timezone_rc=1
    do_install_brew    || brew_rc=1
    do_install_git     || git_rc=1
    do_install_python  || python_rc=1
    do_install_node    || node_rc=1
    do_install_go      || go_rc=1
    do_install_docker  || docker_rc=1
    do_change_ssh_port || ssh_rc=1

    local SHELL_RC_DISPLAY="${SHELL_RC/#$HOME/~}"

    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}  Summary${NC}"
    echo -e "${CYAN}========================================${NC}"
    [ "$timezone_rc" -eq 0 ] && echo -e "  ${GREEN}✓${NC}  System Timezone (${BFS_TIMEZONE})" || echo -e "  ${RED}✗${NC}  System Timezone (${BFS_TIMEZONE})"
    # Homebrew is macOS-only; omit from summary on Linux to avoid confusion
    if [ "$OS_TYPE" = "macos" ]; then
        [ "$brew_rc"    -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Homebrew"    || echo -e "  ${RED}✗${NC}  Homebrew"
    fi
    [ "$git_rc"     -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Git"          || echo -e "  ${RED}✗${NC}  Git"
    [ "$python_rc"  -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Python3"      || echo -e "  ${RED}✗${NC}  Python3"
    [ "$node_rc"    -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Node.js"      || echo -e "  ${RED}✗${NC}  Node.js"
    [ "$go_rc"      -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Go"           || echo -e "  ${RED}✗${NC}  Go"
    [ "$docker_rc"  -eq 0 ] && echo -e "  ${GREEN}✓${NC}  Docker"       || echo -e "  ${RED}✗${NC}  Docker"
    # SSH Port is Linux-only; omit from summary on macOS
    if [ "$OS_TYPE" = "linux" ]; then
        [ "$ssh_rc"     -eq 0 ] && echo -e "  ${GREEN}✓${NC}  SSH Port"    || echo -e "  ${RED}✗${NC}  SSH Port"
    fi
    echo -e "${CYAN}========================================${NC}"

    echo -e "\n${YELLOW}[Reminder] To apply PATH changes in your current terminal:${NC}"
    echo -e "  ${CYAN}source ${SHELL_RC_DISPLAY}${NC}"
}

# =============================================================================
# Help
# =============================================================================

print_help() {
    cat <<EOF
BitsFactor Environment Setup v${VERSION}

Usage:
  bash env.sh                 # interactive menu
  bash env.sh <command> [arg]

Commands:
  install-all                 Install the common toolchain
  set-timezone <tz>           Update system timezone
  install-brew                Install Homebrew (macOS)
  install-git                 Install Git
  install-python              Install Python 3 and venv support
  install-node                Install Node.js and npm
  install-go                  Install the Go toolchain
  install-docker              Install Docker
  ssh-port [port]             Change SSH port on Linux
  help                        Show this help
EOF
}

# =============================================================================
# CLI parameter handling — direct subcommand execution
# =============================================================================

if [ $# -gt 0 ]; then
    case "$1" in
        help|-h|--help) print_help ;;
        install-all)    do_install_all ;;
        set-timezone)   do_set_timezone "${2:-}" ;;
        install-brew)   do_install_brew ;;
        install-git)    do_install_git ;;
        install-python) do_install_python ;;
        install-node)   do_install_node ;;
        install-go)     do_install_go ;;
        install-docker) do_install_docker ;;
        ssh-port)       do_change_ssh_port "${2:-}" ;;
        *)
            echo -e "${RED}[Error] Unknown command: $1${NC}"
            print_help
            exit 1
            ;;
    esac
    exit 0
fi

# =============================================================================
# Entry menu
# =============================================================================

echo -e "${BLUE}======== BitsFactor Environment Setup v${VERSION} ========${NC}"
echo -e "Detected OS:   ${CYAN}${OS_TYPE}${NC}"
echo -e "Shell config:  ${CYAN}${SHELL_RC/#$HOME/~}${NC}\n"

echo -e "${CYAN}Select an option:${NC}"
if [ "$OS_TYPE" = "macos" ]; then
    echo -e "  ${GREEN}1)${NC} Install All          - timezone, Brew, Git, Python, Node, Go, Docker"
else
    echo -e "  ${GREEN}1)${NC} Install All          - timezone, Git, Python, Node, Go, Docker, then optional SSH port"
fi
echo -e "  ${GREEN}2)${NC} Set System Timezone  - update the system timezone ${YELLOW}[default: ${BFS_TIMEZONE}]${NC}"
echo -e "  ${GREEN}3)${NC} Install Homebrew     - install Homebrew ${YELLOW}[macOS only]${NC}"
echo -e "  ${GREEN}4)${NC} Install Git          - install Git"
echo -e "  ${GREEN}5)${NC} Install Python3      - install Python 3 and venv support"
echo -e "  ${GREEN}6)${NC} Install Node.js      - install Node.js and npm"
echo -e "  ${GREEN}7)${NC} Install Go           - install the Go toolchain"
echo -e "  ${GREEN}8)${NC} Install Docker       - install Docker"
echo -e "  ${GREEN}9)${NC} Change SSH Port      - update SSH from the default Linux port ${YELLOW}[Linux only]${NC}"
echo -e "  ${RED}0)${NC} Exit"
echo ""
tty_read MENU_CHOICE "Enter option (0-9): "

case "$MENU_CHOICE" in
    1) do_install_all ;;
    2) do_set_timezone ;;
    3) do_install_brew ;;
    4) do_install_git ;;
    5) do_install_python ;;
    6) do_install_node ;;
    7) do_install_go ;;
    8) do_install_docker ;;
    9) do_change_ssh_port ;;
    0|"")
        echo -e "${YELLOW}Exited.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[Error] Invalid option: $MENU_CHOICE${NC}"
        exit 1
        ;;
esac
