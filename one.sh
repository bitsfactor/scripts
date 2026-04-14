#!/bin/bash

# =============================================================================
# BitsFactor One-Click VPS Initializer
# Orchestrates env.sh, git.sh, claude.sh to set up a new VPS in one command.
# Supports macOS and Linux (Debian / Ubuntu).
#
# Usage:
#   bash one.sh
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

# TTY overrides used by the local test harness
: "${BFS_TTY_OUT:=/dev/tty}"
[ -n "${BFS_TTY_INPUT_FILE:-}" ] && exec 9< "$BFS_TTY_INPUT_FILE"

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

# OS detection
UNAME_S="$(uname -s)"
case "$UNAME_S" in
    MINGW*|MSYS*|CYGWIN*)
        echo -e "${RED}[Error] Native Windows shells are not supported.${NC}"
        echo -e "${YELLOW}Please run this script inside WSL2 Ubuntu on Windows, or use macOS/Linux.${NC}"
        exit 1
        ;;
esac

case "$(printf '%s' "$UNAME_S" | tr '[:upper:]' '[:lower:]')" in
    linux*)  IS_LINUX=true ;;
    *)       IS_LINUX=false ;;
esac

# Detect shell RC
USER_SHELL="$(basename "${SHELL:-/bin/bash}")"
case "$USER_SHELL" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    *)
        if [ "$IS_LINUX" = true ]; then
            SHELL_RC="$HOME/.bashrc"
        else
            SHELL_RC="$HOME/.bash_profile"
        fi
        ;;
esac

reload_shell_rc() {
    local rc_display="${SHELL_RC/#$HOME/~}"

    if [ ! -f "$SHELL_RC" ]; then
        return 0
    fi

    echo -e "\n${BLUE}[Info] Reloading ${rc_display} for later steps...${NC}"
    . "$SHELL_RC" || true
}

# =============================================================================
# Download phase — fetch scripts to temp directory
# =============================================================================

TMP_DIR=$(mktemp -d)
cleanup_tmp_dir() {
    rm -rf "$TMP_DIR"
}
trap 'cleanup_tmp_dir; exit 130' INT TERM
trap 'cleanup_tmp_dir' EXIT

SCRIPTS=("version.sh" "env.sh" "git.sh" "claude.sh" "codex.sh")

echo -e "${BLUE}Downloading scripts...${NC}"
for script in "${SCRIPTS[@]}"; do
    if ! curl -fsSL "${CDN_BASE}/${script}" -o "${TMP_DIR}/${script}"; then
        echo -e "${RED}[Error] Failed to download ${script}${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} ${script}"
done

# =============================================================================
# Welcome
# =============================================================================

stty sane < /dev/tty 2>/dev/null || true

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  BitsFactor One-Click VPS Setup v${VERSION}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

AI_CHOICE=""
while :; do
    echo -e "${CYAN}Choose AI assistant to install:${NC}"
    echo -e "  ${GREEN}1)${NC} Claude Code        - install Claude Code and configure its API"
    echo -e "  ${GREEN}2)${NC} Codex              - install Codex CLI and configure its API"
    tty_read AI_OPTION "Enter option (1-2): "
    case "$AI_OPTION" in
        1) AI_CHOICE="claude"; break ;;
        2) AI_CHOICE="codex"; break ;;
        *) echo -e "${RED}[Error] Invalid option: $AI_OPTION${NC}" ;;
    esac
    echo ""
done

echo ""
STEP_NAMES=("Install dev tools" "Set SSH private key")
if [ "$AI_CHOICE" = "claude" ]; then
    STEP_NAMES+=("Install Claude Code" "Configure Claude API")
    if [ "$IS_LINUX" = true ]; then
        STEP_NAMES+=("Trust All Tools")
    fi
else
    STEP_NAMES+=("Install Codex" "Configure Codex API")
fi
TOTAL=${#STEP_NAMES[@]}

echo -e "${CYAN}This will run the following steps:${NC}"
for i in "${!STEP_NAMES[@]}"; do
    echo -e "  ${GREEN}Step $((i+1))/${TOTAL}${NC}  ${STEP_NAMES[$i]}"
done
echo ""
echo -e "${YELLOW}Each step will ask for confirmation before running.${NC}"
echo ""

# =============================================================================
# run_step — execute one step with confirmation
# =============================================================================

# Result tracking: 0=success, 1=failed, 2=skipped
RESULTS=()
ABORTED=false

run_step() {
    if [ "$ABORTED" = true ]; then
        RESULTS+=("2")
        return 0
    fi

    local step_num="$1"
    local total="$2"
    local script_file="$3"
    local subcommand="$4"
    local description="$5"

    echo -e "\n${BLUE}──────────────────────────────────────────────${NC}"
    echo -e "${BLUE}  [Step ${step_num}/${total}] ${description}${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}→ ${script_file} ${subcommand}${NC}"
    echo ""

    local interrupted=false
    trap 'interrupted=true' INT
    tty_read confirm "  Run this step? [Y/n]: "
    trap 'true' INT
    if [ "$interrupted" = true ] || [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "  ${YELLOW}[Skipped]${NC}"
        RESULTS+=("2")
        return 0
    fi

    echo ""
    if bash "${TMP_DIR}/${script_file}" "$subcommand" < /dev/null; then
        RESULTS+=("0")
    else
        RESULTS+=("1")
        echo -e "\n  ${RED}[Failed] ${description}${NC}"
        interrupted=false
        trap 'interrupted=true' INT
        tty_read cont "  Continue to next step? [Y/n]: "
        trap 'true' INT
        if [ "$interrupted" = true ] || [[ "$cont" =~ ^[Nn]$ ]]; then
            echo -e "${RED}[Aborted] Setup stopped by user.${NC}"
            ABORTED=true
        fi
    fi
    stty sane < /dev/tty 2>/dev/null || true
}

# =============================================================================
# Execute steps
# =============================================================================

set +e  # run_step handles errors explicitly; disable errexit to prevent silent exits
trap 'true' INT TERM  # during steps: absorb signals so Ctrl+C only kills the child process

run_step 1 $TOTAL "env.sh" "install-all" "${STEP_NAMES[0]}"
if [ "${RESULTS[0]:-2}" = "0" ]; then
    reload_shell_rc
fi
run_step 2 $TOTAL "git.sh" "set-key"     "${STEP_NAMES[1]}"
if [ "$AI_CHOICE" = "claude" ]; then
    run_step 3 $TOTAL "claude.sh" "install"   "${STEP_NAMES[2]}"
    run_step 4 $TOTAL "claude.sh" "set-api"   "${STEP_NAMES[3]}"
    if [ "$IS_LINUX" = true ]; then
        run_step 5 $TOTAL "claude.sh" "trust-all" "${STEP_NAMES[4]}"
    fi
else
    run_step 3 $TOTAL "codex.sh" "install"   "${STEP_NAMES[2]}"
    run_step 4 $TOTAL "codex.sh" "set-api"   "${STEP_NAMES[3]}"
fi

trap - INT TERM  # restore default signal handling after steps

# =============================================================================
# Summary
# =============================================================================

echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Setup Complete${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

for i in "${!STEP_NAMES[@]}"; do
    step_result="${RESULTS[$i]:-2}"
    case "$step_result" in
        0) echo -e "  ${GREEN}✓${NC}  ${STEP_NAMES[$i]}" ;;
        1) echo -e "  ${RED}✗${NC}  ${STEP_NAMES[$i]}" ;;
        2) echo -e "  ${YELLOW}–${NC}  ${STEP_NAMES[$i]}  ${YELLOW}(skipped)${NC}" ;;
    esac
done

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

# Detect shell RC for reminder
USER_SHELL="$(basename "${SHELL:-/bin/bash}")"
case "$USER_SHELL" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    *)
        if [ "$IS_LINUX" = true ]; then
            SHELL_RC="$HOME/.bashrc"
        else
            SHELL_RC="$HOME/.bash_profile"
        fi
        ;;
esac

echo -e "\n${YELLOW}[Reminder] To apply all PATH/env changes:${NC}"
echo -e "  ${CYAN}source ${SHELL_RC/#$HOME/~}${NC}"
echo -e "  ${YELLOW}Or simply reopen your terminal.${NC}"
