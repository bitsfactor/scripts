# BitsFactor Scripts

A small Bash-first toolkit for setting up a new machine or VPS.

## Support

- macOS
- Linux
- Windows via **WSL2 Ubuntu only**

Native PowerShell / Git Bash / MSYS / Cygwin are not supported.

## Quick Start

### Open the launcher

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/bfs.sh | bash
```

### Run one action directly

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/bfs.sh | bash -s -- codex install
```

### Pin a release

```bash
BFS_VER=1.3.19
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/bfs.sh | BFS_VER=$BFS_VER bash
```

## `bfs.sh` Menu

```text
BitsFactor Unified Launcher v1.3.19

1) Environment setup   - timezone, package managers, and dev tools
2) Git & SSH           - local key retrieval and server key install
3) Claude Code         - install, configure, trust-all, and oosp
4) Codex               - install and configure Codex CLI
5) PyTools             - manage the bundled Python helper scripts
6) VPS bootstrap       - run the guided end-to-end server setup
0) Exit
```

Use the menu if you want guidance. Use direct commands if you already know what you want.

## Direct Usage

```bash
bash bfs.sh
bash bfs.sh --help
bash bfs.sh env install-all
bash bfs.sh codex install
bash bfs.sh git set-key
```

## Script Map

- `bfs.sh` — unified launcher
- `one.sh` — guided VPS bootstrap
- `env.sh` — timezone and common dev tools
- `git.sh` — Git / SSH key setup
- `claude.sh` — Claude Code install and config
- `codex.sh` — Codex install and config
- `pytools.sh` — bundled Python helper tools

## Verification

```bash
bash -n bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh \
  tests/run.sh tests/lib/assert.sh tests/lib/test-helpers.sh

bash tests/run.sh
```

## Release

```bash
VER="$(cut -d= -f2 version.sh | tr -d '\"')"

git add -A
git commit -m "chore: release $VER"
git tag "v$VER"
git push origin main
git push origin "v$VER"
```

## Docs

- [LICENSE](./LICENSE)
- [CHANGELOG](./CHANGELOG.md)
- [CONTRIBUTING](./CONTRIBUTING.md)
- [SECURITY](./SECURITY.md)
- [CODE_OF_CONDUCT](./CODE_OF_CONDUCT.md)
