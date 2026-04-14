#!/bin/bash

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_PATH="$PATH"
REAL_PYTHON3="$(command -v python3 || true)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bitsfactor-tests.XXXXXX")"
trap 'rm -rf "$TEST_TMP_ROOT"' EXIT

create_mock_bin() {
    local dir="$1"
    mkdir -p "$dir"

    cat > "$dir/uname" <<'MOCK'
#!/bin/bash
case "$1" in
    -m) printf '%s\n' "${MOCK_UNAME_M:-x86_64}" ;;
    -r) printf '%s\n' "${MOCK_UNAME_R:-5.15.0}" ;;
    *) printf '%s\n' "${MOCK_UNAME_S:-Darwin}" ;;
esac
MOCK

    cat > "$dir/id" <<'MOCK'
#!/bin/bash
[ "$1" = "-u" ] && { echo 1000; exit 0; }
/usr/bin/id "$@"
MOCK

    cat > "$dir/sudo" <<'MOCK'
#!/bin/bash
"$@"
MOCK

    cat > "$dir/brew" <<'MOCK'
#!/bin/bash
if [ "$1" = "--version" ]; then
    echo "Homebrew 4.0.0"
    exit 0
fi
if [ "$1" = "shellenv" ]; then
    echo 'export PATH="/mock/homebrew/bin:$PATH"'
    exit 0
fi
if [ "$1" = "list" ] && [ "$2" = "--cask" ] && [ "$3" = "claude-code" ]; then
    exit 0
fi
exit 0
MOCK

    cat > "$dir/apt-get" <<'MOCK'
#!/bin/bash
exit 0
MOCK

    cat > "$dir/npm" <<'MOCK'
#!/bin/bash
case "$1" in
    --version) echo "10.0.0" ;;
    prefix) echo "/mock/npm" ;;
    *) exit 0 ;;
esac
MOCK

    cat > "$dir/node" <<'MOCK'
#!/bin/bash
echo "v20.0.0"
MOCK

    cat > "$dir/go" <<'MOCK'
#!/bin/bash
echo "go version go1.23.5 darwin/amd64"
MOCK

    cat > "$dir/docker" <<'MOCK'
#!/bin/bash
echo "Docker version 26.0.0"
MOCK

    cat > "$dir/git" <<'MOCK'
#!/bin/bash
if [ "$1" = "config" ] && [ "$2" = "--global" ] && [ "$3" = "user.name" ] && [ -z "$4" ]; then
    exit 0
fi
if [ "$1" = "config" ] && [ "$2" = "--global" ] && [ "$3" = "user.email" ] && [ -z "$4" ]; then
    exit 0
fi
exit 0
MOCK

    cat > "$dir/claude" <<'MOCK'
#!/bin/bash
echo "claude 1.0.0"
MOCK

    cat > "$dir/codex" <<'MOCK'
#!/bin/bash
echo "codex 1.0.0"
MOCK

    cat > "$dir/systemsetup" <<'MOCK'
#!/bin/bash
if [ "$1" = "-gettimezone" ]; then
    echo "Time Zone: UTC"
    exit 0
fi
exit 0
MOCK

    cat > "$dir/systemctl" <<'MOCK'
#!/bin/bash
exit 0
MOCK

    cat > "$dir/pbcopy" <<'MOCK'
#!/bin/bash
cat >/dev/null
MOCK

    cat > "$dir/xclip" <<'MOCK'
#!/bin/bash
cat >/dev/null
MOCK

    cat > "$dir/wl-copy" <<'MOCK'
#!/bin/bash
cat >/dev/null
MOCK

    cat > "$dir/clip.exe" <<'MOCK'
#!/bin/bash
cat >/dev/null
MOCK

    cat > "$dir/ssh-keyscan" <<'MOCK'
#!/bin/bash
echo "github.com ssh-ed25519 AAAAMOCKHOSTKEY"
MOCK

    cat > "$dir/ssh" <<'MOCK'
#!/bin/bash
echo "Hi mock-user! You've successfully authenticated, but GitHub does not provide shell access."
MOCK

    cat > "$dir/ssh-keygen" <<'MOCK'
#!/bin/bash
if [ "$1" = "-F" ]; then
    exit 1
fi
if [ "$1" = "-y" ] && [ "$2" = "-f" ]; then
    echo "ssh-ed25519 AAAAMOCKPUBLIC mock@bitsfactor"
    exit 0
fi
if [ "$1" = "-t" ]; then
    key_file=""
    while [ $# -gt 0 ]; do
        if [ "$1" = "-f" ]; then
            shift
            key_file="$1"
        fi
        shift || break
    done
    [ -n "$key_file" ] || exit 1
    mkdir -p "$(dirname "$key_file")"
    cat > "$key_file" <<'KEY'
-----BEGIN OPENSSH PRIVATE KEY-----
mock-private-key
-----END OPENSSH PRIVATE KEY-----
KEY
    echo "ssh-ed25519 AAAAMOCKPUBLIC mock@bitsfactor" > "${key_file}.pub"
    exit 0
fi
exit 0
MOCK

    cat > "$dir/python3" <<'MOCK'
#!/bin/bash
if [ "$1" = "--version" ]; then
    echo "Python 3.11.0"
    exit 0
fi
if [ "$1" = "-c" ]; then
    exit 0
fi
if [ "$1" = "-m" ] && [ "$2" = "venv" ]; then
    venv_dir="$3"
    mkdir -p "$venv_dir/bin"
    cat > "$venv_dir/bin/pip" <<'PIP'
#!/bin/bash
exit 0
PIP
    chmod +x "$venv_dir/bin/pip"
    exit 0
fi
if [ -n "$REAL_PYTHON3" ]; then
    exec "$REAL_PYTHON3" "$@"
fi
exit 0
MOCK

    cat > "$dir/curl" <<'MOCK'
#!/bin/bash
log() {
    [ -n "$MOCK_LOG" ] && printf '%s\n' "$1" >> "$MOCK_LOG"
}

output_file=""
url=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o)
            shift
            output_file="$1"
            ;;
        http://*|https://*)
            url="$1"
            ;;
    esac
    shift || break
done

log "$url"

stdout_payload() {
    case "$url" in
        https://data.jsdelivr.com/v1/package/gh/bitsfactor/scripts)
            cat <<'JSON'
{"versions":["1.3.17","1.3.16"]}
JSON
            ;;
        https://api.github.com/repos/bitsfactor/scripts/tags?per_page=1)
            cat <<'JSON'
[{"name":"v1.3.17"}]
JSON
            ;;
        https://go.dev/VERSION?m=text)
            printf 'go1.23.5\n'
            ;;
        *spec/oosp-cn.md|*spec/oosp-en.md)
            printf '# mock oosp\n'
            ;;
        *)
            printf ''
            ;;
    esac
}

write_file_payload() {
    mkdir -p "$(dirname "$output_file")"
    case "$url" in
        *version.sh)
            echo 'VERSION="1.3.17"' > "$output_file"
            ;;
        *install.sh|*get.docker.com|*claude.ai/install.sh)
            cat > "$output_file" <<'SH'
#!/bin/bash
exit 0
SH
            chmod +x "$output_file"
            ;;
        *spec/oosp-cn.md|*spec/oosp-en.md)
            echo '# mock oosp' > "$output_file"
            ;;
        */env.sh|*/git.sh|*/claude.sh|*/codex.sh|*/pytools.sh|*/one.sh)
            script_name="$(basename "$url")"
            cat > "$output_file" <<SH
#!/bin/bash
printf 'REMOTE %s %s\n' "$script_name" "\$*" >> "\${MOCK_LOG}"
exit 0
SH
            chmod +x "$output_file"
            ;;
        */pytools/*.py)
            cat > "$output_file" <<'PY'
#!/usr/bin/env python3
print('ok')
PY
            chmod +x "$output_file"
            ;;
        *)
            : > "$output_file"
            ;;
    esac
}

if [ -n "$output_file" ]; then
    write_file_payload
else
    stdout_payload
fi
MOCK

    chmod +x "$dir"/*
}

create_sandbox() {
    SANDBOX="$(mktemp -d "$TEST_TMP_ROOT/case.XXXXXX")"
    export SANDBOX
    export HOME="$SANDBOX/home"
    export MOCK_LOG="$SANDBOX/mock.log"
    export MOCK_UNAME_S="Darwin"
    export MOCK_UNAME_M="x86_64"
    export MOCK_UNAME_R="5.15.0"
    export BFS_TTY_OUT="/dev/null"
    unset BFS_TTY_INPUT_FILE
    mkdir -p "$HOME/.ssh" "$HOME/.claude" "$HOME/.codex" "$SANDBOX/mock-bin"
    : > "$MOCK_LOG"
    touch "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"
    create_mock_bin "$SANDBOX/mock-bin"
    export PATH="$SANDBOX/mock-bin:$REAL_PATH"
    export REAL_PYTHON3
}

set_test_input() {
    local content="$1"
    local input_file="$SANDBOX/input.txt"
    printf '%s' "$content" > "$input_file"
    export BFS_TTY_INPUT_FILE="$input_file"
}

use_macos() {
    export MOCK_UNAME_S="Darwin"
    export MOCK_UNAME_R="23.0.0"
}

use_linux() {
    export MOCK_UNAME_S="Linux"
    export MOCK_UNAME_R="5.15.0"
}

use_windows() {
    export MOCK_UNAME_S="MINGW64_NT-10.0"
    export MOCK_UNAME_R="10.0"
}

run_capture() {
    local __out_var="$1"
    local __status_var="$2"
    shift 2
    local _captured_output _captured_status
    set +e
    _captured_output=$("$@" 2>&1)
    _captured_status=$?
    set -e
    printf -v "$__out_var" '%s' "$_captured_output"
    printf -v "$__status_var" '%s' "$_captured_status"
}
