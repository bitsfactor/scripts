#!/bin/bash

# =============================================================================
# BitsFactor Unified Launcher
# Default interactive entrypoint for BitsFactor Scripts.
# Supports macOS, Linux, and Windows via WSL2 Ubuntu only.
#
# Usage:
#   bash bfs.sh
#   bash bfs.sh env install-all
#   BFS_VER=1.3.18 bash bfs.sh codex install
# =============================================================================

set -e

# Load version: BFS_VER env var (remote pinned) > local version.sh (development)
_SCRIPT_DIR=""
[ -n "${BASH_SOURCE[0]}" ] && _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd 2>/dev/null)"
[ -n "$_SCRIPT_DIR" ] && [ -f "$_SCRIPT_DIR/version.sh" ] && . "$_SCRIPT_DIR/version.sh"
[ -n "$BFS_VER" ] && VERSION="$BFS_VER"

JSDELIVR_ROOT="https://fastly.jsdelivr.net/gh/bitsfactor/scripts"
JSDELIVR_META_URL="https://data.jsdelivr.com/v1/package/gh/bitsfactor/scripts"
GITHUB_TAGS_URL="https://api.github.com/repos/bitsfactor/scripts/tags?per_page=1"

GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

# TTY overrides used by the local test harness
: "${BFS_TTY_OUT:=/dev/tty}"
[ -n "${BFS_TTY_INPUT_FILE:-}" ] && exec 9< "$BFS_TTY_INPUT_FILE"

UNAME_S="$(uname -s)"
case "$UNAME_S" in
    MINGW*|MSYS*|CYGWIN*)
        echo -e "${RED}[Error] Native Windows shells are not supported.${NC}"
        echo -e "${YELLOW}Please run BitsFactor Scripts inside WSL2 Ubuntu on Windows, or use macOS/Linux.${NC}"
        exit 1
        ;;
    Darwin*) OS_TYPE="macos" ;;
    Linux*)  OS_TYPE="linux" ;;
    *)
        echo -e "${RED}[Error] Unsupported OS: ${UNAME_S}${NC}"
        echo -e "${YELLOW}This launcher only supports macOS, Linux, and Windows via WSL2 Ubuntu.${NC}"
        exit 1
        ;;
esac

is_wsl() {
    [ "$OS_TYPE" = "linux" ] && grep -qi microsoft /proc/version 2>/dev/null
}

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

resolve_latest_version() {
    local version=""

    version=$(curl -fsSL "$JSDELIVR_META_URL" 2>/dev/null | tr -d '\n' | sed -n 's/.*"versions"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -n "$version" ]; then
        printf '%s' "$version"
        return 0
    fi

    version=$(curl -fsSL "$GITHUB_TAGS_URL" 2>/dev/null | tr -d '\n' | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/p')
    if [ -n "$version" ]; then
        printf '%s' "$version"
        return 0
    fi

    return 1
}

resolve_effective_version() {
    if [ -n "$BFS_VER" ]; then
        printf '%s' "$BFS_VER"
        return 0
    fi

    if [ -n "$VERSION" ] && [ -n "$_SCRIPT_DIR" ] && [ -f "$_SCRIPT_DIR/version.sh" ]; then
        printf '%s' "$VERSION"
        return 0
    fi

    resolve_latest_version
}

EFFECTIVE_VERSION="$(resolve_effective_version || true)"
if [ -z "$EFFECTIVE_VERSION" ]; then
    echo -e "${RED}[Error] Failed to resolve the latest BitsFactor release version.${NC}"
    echo -e "${YELLOW}Please retry later or set BFS_VER explicitly for a pinned run.${NC}"
    exit 1
fi

: "${CDN_BASE:=${JSDELIVR_ROOT}@v${EFFECTIVE_VERSION}}"

TMP_DIR=""
SCRIPT_PATH_RESULT=""
ensure_tmp_dir() {
    if [ -z "$TMP_DIR" ]; then
        TMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TMP_DIR"' EXIT
    fi
}

ensure_script_path() {
    local script_name="$1"

    if [ -n "$_SCRIPT_DIR" ] && [ -f "$_SCRIPT_DIR/$script_name" ]; then
        SCRIPT_PATH_RESULT="$_SCRIPT_DIR/$script_name"
        return 0
    fi

    ensure_tmp_dir
    if [ ! -f "$TMP_DIR/$script_name" ]; then
        if ! curl -fsSL "${CDN_BASE}/${script_name}" -o "$TMP_DIR/$script_name"; then
            echo -e "${RED}[Error] Failed to download ${script_name} from ${CDN_BASE}.${NC}" >&2
            return 1
        fi
        chmod +x "$TMP_DIR/$script_name"
    fi

    SCRIPT_PATH_RESULT="$TMP_DIR/$script_name"
}

run_script() {
    local script_name="$1"
    shift || true

    ensure_script_path "$script_name" || return 1

    BFS_VER="$EFFECTIVE_VERSION" \
    CDN_BASE="$CDN_BASE" \
    BFS_TTY_OUT="$BFS_TTY_OUT" \
    BFS_TTY_INPUT_FILE="${BFS_TTY_INPUT_FILE:-}" \
    bash "$SCRIPT_PATH_RESULT" "$@"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  BitsFactor Unified Launcher v${EFFECTIVE_VERSION}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "Detected OS: ${CYAN}${OS_TYPE}${NC}"
    if is_wsl; then
        echo -e "Windows mode: ${GREEN}WSL detected${NC}"
    elif [ "$OS_TYPE" = "linux" ]; then
        echo -e "Windows mode: ${YELLOW}Not running inside WSL${NC}"
    fi
    echo -e "Resolved release: ${CYAN}v${EFFECTIVE_VERSION}${NC}"
    echo ""
}

print_help() {
    cat <<EOF2
Usage:
  bash bfs.sh                         # interactive launcher
  bash bfs.sh <group> <action> [args] # direct dispatch

Groups:
  env      git      claude      codex      pytools      one

Examples:
  bash bfs.sh env install-all
  bash bfs.sh codex set-api
  BFS_VER=1.3.18 bash bfs.sh claude install
EOF2
}

run_group_action() {
    local group="$1"
    local action="${2:-}"
    shift 2 2>/dev/null || true

    case "$group" in
        env)
            [ -n "$action" ] || { echo -e "${RED}[Error] Missing env action.${NC}"; return 1; }
            run_script "env.sh" "$action" "$@"
            ;;
        git)
            [ -n "$action" ] || { echo -e "${RED}[Error] Missing git action.${NC}"; return 1; }
            run_script "git.sh" "$action" "$@"
            ;;
        claude)
            [ -n "$action" ] || { echo -e "${RED}[Error] Missing claude action.${NC}"; return 1; }
            run_script "claude.sh" "$action" "$@"
            ;;
        codex)
            [ -n "$action" ] || { echo -e "${RED}[Error] Missing codex action.${NC}"; return 1; }
            run_script "codex.sh" "$action" "$@"
            ;;
        pytools)
            [ -n "$action" ] || { echo -e "${RED}[Error] Missing pytools action.${NC}"; return 1; }
            run_script "pytools.sh" "$action" "$@"
            ;;
        one)
            if [ -n "$action" ]; then
                run_script "one.sh" "$action" "$@"
            else
                run_script "one.sh"
            fi
            ;;
        help|-h|--help)
            print_help
            ;;
        *)
            echo -e "${RED}[Error] Unknown group: ${group}${NC}"
            print_help
            return 1
            ;;
    esac
}

run_env_menu() {
    echo -e "${CYAN}Environment Setup${NC}"
    echo -e "  ${GREEN}1)${NC} Install all          - set timezone and install the common toolchain"
    echo -e "  ${GREEN}2)${NC} Set timezone         - update the system timezone"
    echo -e "  ${GREEN}3)${NC} Install Homebrew    - install Homebrew on macOS"
    echo -e "  ${GREEN}4)${NC} Install Git         - install Git"
    echo -e "  ${GREEN}5)${NC} Install Python3     - install Python 3 and venv support"
    echo -e "  ${GREEN}6)${NC} Install Node.js      - install Node.js and npm"
    echo -e "  ${GREEN}7)${NC} Install Go          - install the Go toolchain"
    echo -e "  ${GREEN}8)${NC} Install Docker      - install Docker"
    echo -e "  ${GREEN}9)${NC} Change SSH port     - update SSH from the default Linux port"
    echo -e "  ${RED}0)${NC} Back"
    tty_read choice "Enter option (0-9): "
    case "$choice" in
        1) run_group_action env install-all ;;
        2) run_group_action env set-timezone ;;
        3) run_group_action env install-brew ;;
        4) run_group_action env install-git ;;
        5) run_group_action env install-python ;;
        6) run_group_action env install-node ;;
        7) run_group_action env install-go ;;
        8) run_group_action env install-docker ;;
        9) run_group_action env ssh-port ;;
        0|"") return 0 ;;
        *) echo -e "${RED}[Error] Invalid option: ${choice}${NC}" ;;
    esac
}

run_git_menu() {
    echo -e "${CYAN}Git & SSH${NC}"
    echo -e "  ${GREEN}1)${NC} Retrieve keys        - inspect or generate local SSH keys"
    echo -e "  ${GREEN}2)${NC} Set key              - install a private key on this machine"
    echo -e "  ${RED}0)${NC} Back"
    tty_read choice "Enter option (0/1/2): "
    case "$choice" in
        1) run_group_action git get-key ;;
        2) run_group_action git set-key ;;
        0|"") return 0 ;;
        *) echo -e "${RED}[Error] Invalid option: ${choice}${NC}" ;;
    esac
}

run_claude_menu() {
    echo -e "${CYAN}Claude Code${NC}"
    echo -e "  ${GREEN}1)${NC} Install / Update    - install or upgrade Claude Code"
    echo -e "  ${GREEN}2)${NC} Configure API      - write Anthropic API settings"
    echo -e "  ${GREEN}3)${NC} Trust All Tools    - allow Claude Code to use all tools"
    echo -e "  ${GREEN}4)${NC} Install / Update oosp - sync the oosp prompt file"
    echo -e "  ${RED}5)${NC} Uninstall            - remove Claude Code and related config"
    echo -e "  ${RED}0)${NC} Back"
    tty_read choice "Enter option (0-5): "
    case "$choice" in
        1) run_group_action claude install ;;
        2) run_group_action claude set-api ;;
        3) run_group_action claude trust-all ;;
        4) run_group_action claude install-oosp ;;
        5) run_group_action claude uninstall ;;
        0|"") return 0 ;;
        *) echo -e "${RED}[Error] Invalid option: ${choice}${NC}" ;;
    esac
}

run_codex_menu() {
    echo -e "${CYAN}Codex${NC}"
    echo -e "  ${GREEN}1)${NC} Install Codex       - install Codex CLI and helper alias"
    echo -e "  ${GREEN}2)${NC} Configure API      - write Codex API settings and config"
    echo -e "  ${RED}0)${NC} Back"
    tty_read choice "Enter option (0-2): "
    case "$choice" in
        1) run_group_action codex install ;;
        2) run_group_action codex set-api ;;
        0|"") return 0 ;;
        *) echo -e "${RED}[Error] Invalid option: ${choice}${NC}" ;;
    esac
}

run_pytools_menu() {
    echo -e "${CYAN}PyTools${NC}"
    echo -e "  ${GREEN}1)${NC} Install / Update    - install the Python helper tools"
    echo -e "  ${RED}2)${NC} Uninstall            - remove PyTools and PATH entries"
    echo -e "  ${RED}0)${NC} Back"
    tty_read choice "Enter option (0/1/2): "
    case "$choice" in
        1) run_group_action pytools install ;;
        2) run_group_action pytools uninstall ;;
        0|"") return 0 ;;
        *) echo -e "${RED}[Error] Invalid option: ${choice}${NC}" ;;
    esac
}

run_one_menu() {
    echo -e "${CYAN}VPS Bootstrap${NC}"
    echo -e "  ${GREEN}1)${NC} Run guided setup     - bootstrap a VPS with the common flow"
    echo -e "  ${RED}0)${NC} Back"
    tty_read choice "Enter option (0/1): "
    case "$choice" in
        1) run_group_action one ;;
        0|"") return 0 ;;
        *) echo -e "${RED}[Error] Invalid option: ${choice}${NC}" ;;
    esac
}

interactive_menu() {
    while :; do
        print_header
        echo -e "${CYAN}Choose a tool:${NC}"
        echo -e "  ${GREEN}1)${NC} Environment setup   - timezone, package managers, and dev tools"
        echo -e "  ${GREEN}2)${NC} Git & SSH           - local key retrieval and server key install"
        echo -e "  ${GREEN}3)${NC} Claude Code        - install, configure, trust-all, and oosp"
        echo -e "  ${GREEN}4)${NC} Codex              - install and configure Codex CLI"
        echo -e "  ${GREEN}5)${NC} PyTools            - manage the bundled Python helper scripts"
        echo -e "  ${GREEN}6)${NC} VPS bootstrap       - run the guided end-to-end server setup"
        echo -e "  ${RED}0)${NC} Exit"
        echo -e "${YELLOW}Tip:${NC} You can skip menus with commands like ${CYAN}bash bfs.sh codex install${NC}"
        echo ""
        tty_read menu_choice "Enter option (0-6): "

        case "$menu_choice" in
            1) run_env_menu ;;
            2) run_git_menu ;;
            3) run_claude_menu ;;
            4) run_codex_menu ;;
            5) run_pytools_menu ;;
            6) run_one_menu ;;
            0|"")
                echo -e "${YELLOW}Exited.${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}[Error] Invalid option: ${menu_choice}${NC}"
                ;;
        esac

        echo ""
        tty_read _continue "Press Enter to return to the main menu..."
    done
}

if [ $# -gt 0 ]; then
    run_group_action "$@"
    exit $?
fi

interactive_menu
