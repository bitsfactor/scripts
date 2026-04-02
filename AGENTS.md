# Repository Guidelines

## Project Structure & Module Organization

This repository is a small collection of versioned Bash setup tools for local machines and remote VPS bootstrap. The top-level scripts are the product:

- `one.sh`: orchestrates full machine bootstrap
- `env.sh`: installs system dependencies and base tooling
- `git.sh`: configures Git and SSH access
- `claude.sh`: installs/configures Claude Code
- `codex.sh`: installs/configures Codex
- `pytools.sh`: installs Python CLI helpers
- `version.sh`: single source of truth for `BFS_VER`

Supporting content lives in:

- `pytools/`: standalone Python utilities
- `promp/`: prompt and setup reference docs
- `spec/`: product/specification notes
- `README.md`: user-facing usage examples

Scripts are standalone and are commonly executed either locally with `bash <script>.sh` or remotely through jsDelivr with `curl | bash`.

## Build, Test, and Development Commands

There is no build system. Work directly on the scripts and validate them locally.

- `bash one.sh` or `bash claude.sh`: run a script interactively
- `bash -n claude.sh`: syntax-check a Bash script without executing it
- `bash -n *.sh`: quick repo-wide syntax pass
- `python3 pytools/dogecloud.py --help`: inspect Python utility usage
- `rg "pattern"`: search the repo quickly
- `BFS_VER=1.3.15; curl -fsSL https://fastly.jsdelivr.net/gh/bitsfactor/scripts@v$BFS_VER/claude.sh | BFS_VER=$BFS_VER bash`: test the published remote-install pattern

When changing versioned install examples, update both `version.sh` and matching `BFS_VER=...` snippets in `README.md`.

## Coding Style & Naming Conventions

Use Bash with `set -e`, 4-space indentation, and clear function names such as `do_set_api` or `clean_shell_config`. Prefer uppercase names for exported env vars and shared constants, and lowercase snake_case for local variables and functions. Keep scripts portable across macOS and Linux; wrap platform-specific behavior in helpers like `sed_inplace`.

Comments should explain non-obvious behavior, not restate the code. Use ANSI color output consistently for user-facing status messages. Keep compatibility with macOS and Linux, especially Debian/Ubuntu. When clipboard support is needed, prefer cross-platform fallbacks (`pbcopy`, `xclip`, `wl-copy`, `clip.exe`). For SSH keys, prefer `ed25519`; only fall back to RSA when necessary.

## Testing Guidelines

There is no formal test suite yet. Minimum validation for script changes:

- run `bash -n` on every edited `.sh` file
- execute the changed script path locally when safe
- verify interactive prompts, file writes, and shell config updates manually

For Python changes, run the affected tool directly with sample arguments or `--help`.

## Commit & Pull Request Guidelines

Recent history uses short imperative messages, often with Conventional Commit prefixes, for example `fix: address review issues in setup scripts` and `chore: bump version to 1.3.15`. Follow that pattern.

PRs should include:

- a concise summary of behavior changes
- impacted scripts and platforms (`macOS`, `Linux`, or both)
- manual verification steps performed
- screenshots or terminal excerpts only when prompt/output changes matter

## Release Process

For a release, bump the patch version in `version.sh`, update all `BFS_VER=...` examples in `README.md`, then commit, tag, and push. Standard flow:

```bash
VER="$(cut -d= -f2 version.sh | tr -d '\"')"
# edit version.sh and README.md first, then:
git add -A
git commit -m "chore: bump version to $VER"
git tag "v$VER"
git push origin main
git push origin "v$VER"
```

Keep the commit message and tag version identical. Do not create a release tag until `README.md` and `version.sh` are in sync. Published jsDelivr tags are immutable, so verify the version before pushing.

## Security & Configuration Tips

Do not commit secrets, API keys, private SSH material, or machine-specific shell config. Treat edits to installer URLs, PATH mutations, and shell RC writes as high-risk and verify them carefully.
