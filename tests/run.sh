#!/bin/bash
set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/lib/assert.sh"
. "$(cd "$(dirname "$0")" && pwd)/lib/test-helpers.sh"

pass_count=0
case_count=0

run_case() {
    local name="$1"
    local fn="$2"
    case_count=$((case_count + 1))
    echo "== $name =="
    "$fn"
    pass_count=$((pass_count + 1))
}

assert_success_case() {
    local label="$1"
    local os="$2"
    local input="${3:-}"
    shift 3 || true

    create_sandbox
    case "$os" in
        macos) use_macos ;;
        linux) use_linux ;;
        windows) use_windows ;;
    esac
    [ -n "$input" ] && set_test_input "$input"

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="${BFS_TTY_INPUT_FILE:-}" REAL_PYTHON3="$REAL_PYTHON3" "$@"
    assert_eq 0 "$status" "expected success for $label"
    assert_not_contains "$output" "[Error]" "unexpected error output for $label"
}

assert_windows_fail_case() {
    local script_path="$1"
    create_sandbox
    use_windows
    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" REAL_PYTHON3="$REAL_PYTHON3" bash "$script_path"
    assert_eq 1 "$status" "expected native Windows fast-fail for $script_path"
    assert_contains "$output" "WSL2 Ubuntu" "expected WSL2 guidance in $script_path"
}

case_launcher_menu_renders() {
    create_sandbox
    use_macos
    set_test_input $'0\n'
    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/bfs.sh"
    assert_eq 0 "$status"
    assert_contains "$output" "BitsFactor Unified Launcher"
    assert_contains "$output" "Choose a tool"
    assert_not_contains "$output" "fail2ban"
}

case_windows_fast_fail() {
    local script
    for script in bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh; do
        assert_windows_fail_case "$TEST_ROOT/$script"
    done
}

case_remote_latest_resolution() {
    create_sandbox
    use_macos
    local remote_dir="$SANDBOX/remote"
    mkdir -p "$remote_dir"
    cp "$TEST_ROOT/bfs.sh" "$remote_dir/bfs.sh"

    local output status log_contents
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" REAL_PYTHON3="$REAL_PYTHON3" bash "$remote_dir/bfs.sh" env install-all
    assert_eq 0 "$status"
    log_contents="$(cat "$MOCK_LOG")"
    assert_contains "$log_contents" "https://data.jsdelivr.com/v1/package/gh/bitsfactor/scripts"
    assert_contains "$log_contents" "https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v1.3.17/env.sh"
}

case_remote_pinned_resolution() {
    create_sandbox
    use_macos
    local remote_dir="$SANDBOX/remote"
    mkdir -p "$remote_dir"
    cp "$TEST_ROOT/bfs.sh" "$remote_dir/bfs.sh"

    local output status log_contents
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_VER="1.3.16" REAL_PYTHON3="$REAL_PYTHON3" bash "$remote_dir/bfs.sh" env install-all
    assert_eq 0 "$status"
    log_contents="$(cat "$MOCK_LOG")"
    assert_not_contains "$log_contents" "https://data.jsdelivr.com/v1/package/gh/bitsfactor/scripts"
    assert_contains "$log_contents" "https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v1.3.16/env.sh"
}

case_direct_scripts() {
    assert_success_case "env install-all" macos "" bash "$TEST_ROOT/env.sh" install-all
    assert_success_case "env set-timezone" macos "" bash "$TEST_ROOT/env.sh" set-timezone Asia/Shanghai
    assert_success_case "env install-brew" macos "" bash "$TEST_ROOT/env.sh" install-brew
    assert_success_case "env install-git" macos "" bash "$TEST_ROOT/env.sh" install-git
    assert_success_case "env install-python" macos "" bash "$TEST_ROOT/env.sh" install-python
    assert_success_case "env install-node" macos "" bash "$TEST_ROOT/env.sh" install-node
    assert_success_case "env install-go" macos "" bash "$TEST_ROOT/env.sh" install-go
    assert_success_case "env install-docker" macos "" bash "$TEST_ROOT/env.sh" install-docker

    create_sandbox
    use_linux
    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\n' > "$sshd_config"
    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" ssh-port 60101
    assert_eq 0 "$status"
    assert_contains "$(cat "$sshd_config")" "Port 60101"

    create_sandbox
    use_macos
    mkdir -p "$HOME/.ssh"
    printf 'mock-private' > "$HOME/.ssh/id_ed25519"
    printf 'ssh-ed25519 AAAAMOCKPUBLIC\n' > "$HOME/.ssh/id_ed25519.pub"
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/git.sh" get-key
    assert_eq 0 "$status"
    assert_contains "$output" "option 3"

    create_sandbox
    use_macos
    mkdir -p "$HOME/.ssh"
    printf 'mock-private' > "$HOME/.ssh/id_ed25519"
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/git.sh" get-key
    assert_eq 0 "$status"
    assert_contains "$output" "Rebuilding the matching public key"
    assert_contains "$output" "ssh-ed25519 AAAAMOCKPUBLIC"
    test -f "$HOME/.ssh/id_ed25519.pub"

    create_sandbox
    use_macos
    set_test_input $'y\n'
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/git.sh" get-pubkey
    assert_eq 0 "$status"
    assert_contains "$output" "Public key ready"
    test -f "$HOME/.ssh/id_ed25519.pub"

    create_sandbox
    use_macos
    set_test_input $'-----BEGIN OPENSSH PRIVATE KEY-----\nmock-private-key\n-----END OPENSSH PRIVATE KEY-----\n\n\n\n'
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/git.sh" set-key
    assert_eq 0 "$status"
    test -f "$HOME/.ssh/id_ed25519"

    create_sandbox
    use_macos
    mkdir -p "$HOME/.ssh"
    printf 'existing-private-key' > "$HOME/.ssh/id_ed25519"
    set_test_input $'-----BEGIN OPENSSH PRIVATE KEY-----\nmock-private-key\n-----END OPENSSH PRIVATE KEY-----\n\nn\n'
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/git.sh" set-key
    assert_eq 1 "$status"
    assert_contains "$output" "[Cancelled] Operation cancelled."
    assert_contains "$(cat "$HOME/.ssh/id_ed25519")" "existing-private-key"

    assert_success_case "claude install" macos "" bash "$TEST_ROOT/claude.sh" install
    assert_success_case "claude set-api" macos $'api.develop.cc\nmock-token\n' bash "$TEST_ROOT/claude.sh" set-api
    assert_success_case "claude trust-all" macos "" bash "$TEST_ROOT/claude.sh" trust-all
    assert_success_case "claude install-oosp" macos $'1\n1\n' bash "$TEST_ROOT/claude.sh" install-oosp
    assert_success_case "claude uninstall" macos $'y\n' bash "$TEST_ROOT/claude.sh" uninstall

    assert_success_case "codex install" macos "" bash "$TEST_ROOT/codex.sh" install
    assert_success_case "codex set-api" macos $'api.develop.cc/v1\nmock-openai-key\n' bash "$TEST_ROOT/codex.sh" set-api

    assert_success_case "pytools install" macos "" bash "$TEST_ROOT/pytools.sh" install
    assert_success_case "pytools uninstall" macos $'y\n' bash "$TEST_ROOT/pytools.sh" uninstall

    create_sandbox
    use_macos
    set_test_input $'2\nn\nn\nn\nn\n'
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/one.sh"
    assert_eq 0 "$status"
}

case_ssh_port_compatibility() {
    create_sandbox
    use_linux
    export MOCK_ID_U="0"
    export MOCK_SYSTEMCTL_EXIT="1"
    export MOCK_SERVICE_EXIT="0"

    local sshd_config="$SANDBOX/sshd_config"
    local sshd_dropin_dir="$SANDBOX/sshd_config.d"
    mkdir -p "$sshd_dropin_dir"
    cat > "$sshd_config" <<EOF
Include $sshd_dropin_dir/*.conf

#Port 22
EOF
    printf 'Port 22\n' > "$sshd_dropin_dir/20-vendor.conf"
    printf 'Port 46022\n' > "$sshd_dropin_dir/0-bitsfactor-port.conf"

    local output status log_contents
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_ID_U="$MOCK_ID_U" MOCK_SYSTEMCTL_EXIT="$MOCK_SYSTEMCTL_EXIT" MOCK_SERVICE_EXIT="$MOCK_SERVICE_EXIT" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" ssh-port 60101
    assert_eq 0 "$status"
    assert_contains "$(cat "$sshd_dropin_dir/20-vendor.conf")" "Port 60101"
    assert_not_contains "$(cat "$sshd_config")" "Port 60101"
    test ! -e "$sshd_dropin_dir/0-bitsfactor-port.conf"
    assert_contains "$output" "Removed legacy SSH drop-in"

    log_contents="$(cat "$MOCK_LOG")"
    assert_contains "$log_contents" "systemctl reload sshd"
    assert_contains "$log_contents" "service sshd reload"
}

case_ssh_port_relative_include_semantics() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    local relative_dir="$SANDBOX/sub"
    mkdir -p "$relative_dir"
    cat > "$sshd_config" <<'EOF'
Include sub/*.conf

#Port 22
EOF
    printf 'Port 22\n' > "$relative_dir/relative.conf"

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" ssh-port 60101
    assert_eq 0 "$status"
    assert_contains "$(cat "$sshd_config")" "Port 60101"
    assert_contains "$(cat "$relative_dir/relative.conf")" "Port 22"
}

case_harden_server_flow() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    local sshd_dropin_dir="$SANDBOX/sshd_config.d"
    mkdir -p "$sshd_dropin_dir"
    cat > "$sshd_config" <<EOF
Include $sshd_dropin_dir/*.conf
Port 22
pubkeyauthentication yes
EOF
    cat > "$sshd_dropin_dir/20-auth.conf" <<'EOF'
passwordauthentication yes
kbdinteractiveauthentication yes
permitrootlogin yes
EOF

    set_test_input $'ssh-ed25519 AAAAHARDENINGKEY mock@test\ny\ny\ny\n'

    local output status log_contents auth_keys_file
    auth_keys_file="$HOME/.ssh/authorized_keys"
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server 60101
    assert_eq 0 "$status"
    assert_contains "$output" "How to get your SSH login public key"
    assert_contains "$output" "https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v"
    assert_contains "$output" "git.sh | bash -s -- get-pubkey"
    assert_not_contains "$output" "fail2ban"
    assert_contains "$(cat "$auth_keys_file")" "ssh-ed25519 AAAAHARDENINGKEY mock@test"
    assert_contains "$(cat "$sshd_config")" "Port 60101"
    assert_contains "$(cat "$sshd_dropin_dir/20-auth.conf")" "PasswordAuthentication no"
    assert_contains "$(cat "$sshd_dropin_dir/20-auth.conf")" "KbdInteractiveAuthentication no"
    assert_contains "$(cat "$sshd_dropin_dir/20-auth.conf")" "PermitRootLogin prohibit-password"

    log_contents="$(cat "$MOCK_LOG")"
    assert_not_contains "$log_contents" "fail2ban"
    assert_contains "$log_contents" "systemctl reload sshd"
}

case_harden_server_cancelled_new_key_blocks_password_disable() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\nPubkeyAuthentication yes\n' > "$sshd_config"
    mkdir -p "$HOME/.ssh"
    printf 'ssh-ed25519 AAAAEXISTING bfs@test\n' > "$HOME/.ssh/authorized_keys"
    set_test_input $'n\n\nn\n'

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server
    assert_eq 0 "$status"
    assert_contains "$output" "not ready for this run"
    assert_contains "$(cat "$sshd_config")" "PasswordAuthentication yes"
    assert_contains "$(cat "$sshd_config")" "PermitRootLogin yes"
}

case_harden_server_existing_key_normalizes_permissions() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\nPubkeyAuthentication yes\n' > "$sshd_config"
    mkdir -p "$HOME/.ssh"
    chmod 755 "$HOME/.ssh"
    printf 'ssh-ed25519 AAAAEXISTING bfs@test\n' > "$HOME/.ssh/authorized_keys"
    chmod 644 "$HOME/.ssh/authorized_keys"
    set_test_input $'\n\nn\n'

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server
    assert_eq 0 "$status"
    assert_eq 700 "$(stat -c '%a' "$HOME/.ssh")"
    assert_eq 600 "$(stat -c '%a' "$HOME/.ssh/authorized_keys")"
    assert_contains "$output" "Login public key: "
}

case_harden_server_sudo_user_sets_ownership() {
    create_sandbox
    use_linux
    local mock_id_u="0"
    local sudo_user="sandboxuser"
    local mock_getent_user="sandboxuser"
    local mock_getent_home="$SANDBOX/login-home"
    local mock_getent_uid="1001"
    local mock_getent_gid="1001"

    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\nPubkeyAuthentication yes\n' > "$sshd_config"
    set_test_input $'ssh-ed25519 AAAASUDOUSER bfs@test\nn\nn\n'

    local output status log_contents
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_ID_U="$mock_id_u" SUDO_USER="$sudo_user" MOCK_GETENT_USER="$mock_getent_user" MOCK_GETENT_HOME="$mock_getent_home" MOCK_GETENT_UID="$mock_getent_uid" MOCK_GETENT_GID="$mock_getent_gid" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server
    assert_eq 0 "$status"
    assert_contains "$output" "Target login account:"
    assert_contains "$output" "sandboxuser"
    assert_contains "$(cat "$SANDBOX/login-home/.ssh/authorized_keys")" "ssh-ed25519 AAAASUDOUSER bfs@test"
    log_contents="$(cat "$MOCK_LOG")"
    assert_contains "$log_contents" "chown sandboxuser"
}

case_harden_server_prefers_runtime_user_over_env_user() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\nPubkeyAuthentication yes\n' > "$sshd_config"
    mkdir -p "$HOME/.ssh"
    printf 'ssh-ed25519 AAAAEXISTING bfs@test\n' > "$HOME/.ssh/authorized_keys"
    set_test_input $'\n\nn\n'

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" USER="stale-env-user" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_ID_UN="actual-login-user" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server
    assert_eq 0 "$status"
    assert_contains "$output" "Login account target: "
    assert_contains "$output" "actual-login-user"
    assert_not_contains "$output" "stale-env-user"
}

case_harden_server_prefers_passwd_home_over_env_home() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    local target_user="actual-login-user"
    local target_home="$SANDBOX/login-home"
    printf 'Port 22\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\nPubkeyAuthentication yes\n' > "$sshd_config"
    set_test_input $'ssh-ed25519 AAAAHOMEFIX bfs@test\nn\nn\n'

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" USER="stale-env-user" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_ID_UN="$target_user" MOCK_GETENT_USER="$target_user" MOCK_GETENT_HOME="$target_home" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server
    assert_eq 0 "$status"
    assert_contains "$output" "authorized_keys path: "
    assert_contains "$output" "$target_home/.ssh/authorized_keys"
    assert_contains "$(cat "$target_home/.ssh/authorized_keys")" "ssh-ed25519 AAAAHOMEFIX bfs@test"
    test ! -f "$HOME/.ssh/authorized_keys"
}

case_ssh_port_lowercase_fallback_paths() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    local sshd_dropin_dir="$SANDBOX/sshd_config.d"
    mkdir -p "$sshd_dropin_dir"
    cat > "$sshd_config" <<EOF
include $sshd_dropin_dir/*.conf
match user deploy
    port 60022
EOF
    printf 'port 22\n' > "$sshd_dropin_dir/lowercase.conf"

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_SSHD_T_EXIT="1" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" ssh-port 60101
    assert_eq 0 "$status"
    assert_contains "$(cat "$sshd_dropin_dir/lowercase.conf")" "Port 60101"
    assert_contains "$(cat "$sshd_config")" "match user deploy"
    assert_contains "$(cat "$sshd_config")" "    port 60022"
    assert_not_contains "$output" "SSH still has Port 22 configured"
}

case_ssh_port_lowercase_commented_port_replaced() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    printf '#port 22\n' > "$sshd_config"

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_SSHD_T_EXIT="1" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" ssh-port 60101
    assert_eq 0 "$status"
    assert_eq "Port 60101" "$(cat "$sshd_config")"
}

case_ssh_port_insert_before_match_without_touching_scoped_port() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    cat > "$sshd_config" <<'EOF'
Match user deploy
    Port 60022
EOF

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_SSHD_T_EXIT="1" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" ssh-port 60101
    assert_eq 0 "$status"
    assert_contains "$(cat "$sshd_config")" $'Port 60101\nMatch user deploy\n    Port 60022'
}

case_ssh_port_validation_failure_rolls_back() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\n' > "$sshd_config"

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_SSHD_VALIDATE_EXIT="1" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" ssh-port 60101
    assert_eq 1 "$status"
    assert_eq "Port 22" "$(cat "$sshd_config")"
    assert_contains "$output" "[Rollback] Restored the previous SSH configuration files."
}

case_harden_server_lowercase_match_stays_scoped() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    cat > "$sshd_config" <<'EOF'
Port 22
PasswordAuthentication yes
KbdInteractiveAuthentication yes
PermitRootLogin yes
PubkeyAuthentication yes
match user deploy
    passwordauthentication yes
EOF
    mkdir -p "$HOME/.ssh"
    printf 'ssh-ed25519 AAAAEXISTING bfs@test\n' > "$HOME/.ssh/authorized_keys"
    set_test_input $'\n\ny\ny\n'

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_SSHD_T_EXIT="1" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server
    assert_eq 0 "$status"
    assert_contains "$output" "SSH password login is now disabled"
    assert_contains "$(cat "$sshd_config")" "PasswordAuthentication no"
    assert_contains "$(cat "$sshd_config")" "match user deploy"
    assert_contains "$(cat "$sshd_config")" "    passwordauthentication yes"
}

case_harden_server_auth_failure_rolls_back_and_returns_nonzero() {
    create_sandbox
    use_linux

    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\nPubkeyAuthentication yes\n' > "$sshd_config"
    mkdir -p "$HOME/.ssh"
    printf 'ssh-ed25519 AAAAEXISTING bfs@test\n' > "$HOME/.ssh/authorized_keys"
    set_test_input $'\n\ny\ny\n'

    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" MOCK_SSHD_VALIDATE_EXIT="1" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/env.sh" harden-server
    assert_eq 1 "$status"
    assert_contains "$output" "SSH auth step: "
    assert_contains "$output" "failed"
    assert_contains "$output" "[Rollback] Restored the previous SSH configuration files."
    assert_contains "$(cat "$sshd_config")" "PasswordAuthentication yes"
    assert_contains "$(cat "$sshd_config")" "KbdInteractiveAuthentication yes"
    assert_contains "$(cat "$sshd_config")" "PermitRootLogin yes"
}

case_launcher_dispatch() {
    assert_success_case "bfs env install-all" macos "" bash "$TEST_ROOT/bfs.sh" env install-all
    assert_success_case "bfs env set-timezone" macos "" bash "$TEST_ROOT/bfs.sh" env set-timezone Asia/Shanghai
    assert_success_case "bfs env install-brew" macos "" bash "$TEST_ROOT/bfs.sh" env install-brew
    assert_success_case "bfs env install-git" macos "" bash "$TEST_ROOT/bfs.sh" env install-git
    assert_success_case "bfs env install-python" macos "" bash "$TEST_ROOT/bfs.sh" env install-python
    assert_success_case "bfs env install-node" macos "" bash "$TEST_ROOT/bfs.sh" env install-node
    assert_success_case "bfs env install-go" macos "" bash "$TEST_ROOT/bfs.sh" env install-go
    assert_success_case "bfs env install-docker" macos "" bash "$TEST_ROOT/bfs.sh" env install-docker

    create_sandbox
    use_linux
    local sshd_config="$SANDBOX/sshd_config"
    printf 'Port 22\n' > "$sshd_config"
    local output status
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_SSHD_CONFIG="$sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/bfs.sh" env ssh-port 60101
    assert_eq 0 "$status"

    create_sandbox
    use_macos
    mkdir -p "$HOME/.ssh"
    printf 'mock-private' > "$HOME/.ssh/id_ed25519"
    printf 'ssh-ed25519 AAAAMOCKPUBLIC\n' > "$HOME/.ssh/id_ed25519.pub"
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/bfs.sh" git get-key
    assert_eq 0 "$status"

    create_sandbox
    use_macos
    mkdir -p "$HOME/.ssh"
    printf 'ssh-ed25519 AAAAMOCKPUBLIC\n' > "$HOME/.ssh/id_ed25519.pub"
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/bfs.sh" git get-pubkey
    assert_eq 0 "$status"

    create_sandbox
    use_macos
    set_test_input $'-----BEGIN OPENSSH PRIVATE KEY-----\nmock-private-key\n-----END OPENSSH PRIVATE KEY-----\n\n\n\n'
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/bfs.sh" git set-key
    assert_eq 0 "$status"

    create_sandbox
    use_linux
    local harden_sshd_config="$SANDBOX/harden-sshd_config"
    printf 'Port 22\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\nPubkeyAuthentication yes\n' > "$harden_sshd_config"
    mkdir -p "$HOME/.ssh"
    printf 'ssh-ed25519 AAAAEXISTING bfs@test\n' > "$HOME/.ssh/authorized_keys"
    set_test_input $'\n\n\n'
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" BFS_SSHD_CONFIG="$harden_sshd_config" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/bfs.sh" env harden-server
    assert_eq 0 "$status"

    assert_success_case "bfs claude install" macos "" bash "$TEST_ROOT/bfs.sh" claude install
    assert_success_case "bfs claude set-api" macos $'api.develop.cc\nmock-token\n' bash "$TEST_ROOT/bfs.sh" claude set-api
    assert_success_case "bfs claude trust-all" macos "" bash "$TEST_ROOT/bfs.sh" claude trust-all
    assert_success_case "bfs claude install-oosp" macos $'1\n1\n' bash "$TEST_ROOT/bfs.sh" claude install-oosp
    assert_success_case "bfs claude uninstall" macos $'y\n' bash "$TEST_ROOT/bfs.sh" claude uninstall

    assert_success_case "bfs codex install" macos "" bash "$TEST_ROOT/bfs.sh" codex install
    assert_success_case "bfs codex set-api" macos $'api.develop.cc/v1\nmock-openai-key\n' bash "$TEST_ROOT/bfs.sh" codex set-api

    assert_success_case "bfs pytools install" macos "" bash "$TEST_ROOT/bfs.sh" pytools install
    assert_success_case "bfs pytools uninstall" macos $'y\n' bash "$TEST_ROOT/bfs.sh" pytools uninstall

    create_sandbox
    use_macos
    set_test_input $'2\nn\nn\nn\nn\n'
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" BFS_TTY_INPUT_FILE="$BFS_TTY_INPUT_FILE" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/bfs.sh" one
    assert_eq 0 "$status"
}

case_help_outputs() {
    local output status

    run_capture output status bash "$TEST_ROOT/bfs.sh" --help
    assert_eq 0 "$status"
    assert_contains "$output" "Usage:"
    assert_contains "$output" "interactive launcher"

    run_capture output status bash "$TEST_ROOT/env.sh" --help
    assert_eq 0 "$status"
    assert_contains "$output" "install-all"
    assert_contains "$output" "harden-server"
    assert_not_contains "$output" "fail2ban"

    run_capture output status bash "$TEST_ROOT/git.sh" --help
    assert_eq 0 "$status"
    assert_contains "$output" "get-key"
    assert_contains "$output" "get-pubkey"

    run_capture output status bash "$TEST_ROOT/claude.sh" --help
    assert_eq 0 "$status"
    assert_contains "$output" "install-oosp"

    run_capture output status bash "$TEST_ROOT/codex.sh" --help
    assert_eq 0 "$status"
    assert_contains "$output" "set-api"

    run_capture output status bash "$TEST_ROOT/pytools.sh" --help
    assert_eq 0 "$status"
    assert_contains "$output" "uninstall"

    create_sandbox
    use_macos
    run_capture output status env HOME="$HOME" PATH="$PATH" MOCK_LOG="$MOCK_LOG" MOCK_UNAME_S="$MOCK_UNAME_S" MOCK_UNAME_R="$MOCK_UNAME_R" MOCK_UNAME_M="$MOCK_UNAME_M" BFS_TTY_OUT="$BFS_TTY_OUT" REAL_PYTHON3="$REAL_PYTHON3" bash "$TEST_ROOT/one.sh" --help
    assert_eq 0 "$status"
    assert_contains "$output" "guided VPS bootstrap"
    assert_not_contains "$output" "Downloading scripts..."
    assert_eq "" "$(cat "$MOCK_LOG")" "expected one.sh --help to avoid remote fetches"
}

run_case "launcher menu renders" case_launcher_menu_renders
run_case "native Windows fast-fail" case_windows_fast_fail
run_case "remote latest resolution locks to a tag" case_remote_latest_resolution
run_case "remote pinned version skips latest lookup" case_remote_pinned_resolution
run_case "direct script command matrix" case_direct_scripts
run_case "ssh port compatibility paths" case_ssh_port_compatibility
run_case "ssh port relative include semantics" case_ssh_port_relative_include_semantics
run_case "server hardening flow" case_harden_server_flow
run_case "cancelled new key blocks password disable" case_harden_server_cancelled_new_key_blocks_password_disable
run_case "existing key path normalizes permissions" case_harden_server_existing_key_normalizes_permissions
run_case "sudo user path sets ownership" case_harden_server_sudo_user_sets_ownership
run_case "runtime user wins over stale USER env" case_harden_server_prefers_runtime_user_over_env_user
run_case "passwd home wins over stale HOME env" case_harden_server_prefers_passwd_home_over_env_home
run_case "ssh port lowercase fallback paths" case_ssh_port_lowercase_fallback_paths
run_case "ssh port lowercase commented port rewrite" case_ssh_port_lowercase_commented_port_replaced
run_case "ssh port inserts before match scope" case_ssh_port_insert_before_match_without_touching_scoped_port
run_case "ssh port validation failure rolls back" case_ssh_port_validation_failure_rolls_back
run_case "lowercase match auth stays scoped" case_harden_server_lowercase_match_stays_scoped
run_case "auth failure rolls back and exits nonzero" case_harden_server_auth_failure_rolls_back_and_returns_nonzero
run_case "launcher direct-dispatch matrix" case_launcher_dispatch
run_case "help outputs" case_help_outputs

echo
printf 'Passed %s/%s test groups\n' "$pass_count" "$case_count"
