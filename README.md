# BitsFactor Scripts

A small Bash-first toolkit for setting up a new machine or VPS.

## Support

- macOS
- Linux
- Windows via **WSL2 Ubuntu only**

Native PowerShell / Git Bash / MSYS / Cygwin are not supported.

## Quick Start

### Default entrypoint

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/bfs.sh | bash
```

### Direct command through launcher

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@main/bfs.sh | bash -s -- codex install
```

### Pinned release

```bash
BFS_VER=1.3.18
curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/bfs.sh | BFS_VER=$BFS_VER bash
```

## Scripts

| Script | Purpose |
| --- | --- |
| `bfs.sh` | Unified launcher |
| `one.sh` | Guided VPS bootstrap |
| `env.sh` | System timezone and development tools |
| `git.sh` | Git / SSH key setup |
| `claude.sh` | Claude Code install and config |
| `codex.sh` | Codex install and config |
| `pytools.sh` | Python helper tools |
| `version.sh` | Release version source of truth |

## Local Usage

```bash
bash bfs.sh
bash bfs.sh env install-all
bash bfs.sh codex install
bash bfs.sh git set-key
```

## Verification

```bash
bash -n bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh \
  tests/run.sh tests/lib/assert.sh tests/lib/test-helpers.sh

bash tests/run.sh
```

## Release

When releasing:
1. bump `version.sh`
2. keep pinned examples in `README.md` in sync
3. commit
4. tag
5. push branch and tag

Example:

```bash
VER="$(cut -d= -f2 version.sh | tr -d '"')"

git add -A
git commit -m "chore: release $VER"
git tag "v$VER"
git push origin main
git push origin "v$VER"
```

## Other Docs

- [LICENSE](./LICENSE)
- [CHANGELOG](./CHANGELOG.md)
- [CONTRIBUTING](./CONTRIBUTING.md)
- [SECURITY](./SECURITY.md)
- [CODE_OF_CONDUCT](./CODE_OF_CONDUCT.md)
