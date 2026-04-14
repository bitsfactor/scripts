# Changelog

All notable changes to this project should be documented in this file.

This file is intentionally starting now as part of the repository polish pass. Older releases exist in Git history and tags, but were not backfilled into a structured changelog.

The format is loosely based on Keep a Changelog, with project-specific wording where useful.

## [Unreleased]

### Added
- unified launcher `bfs.sh` as the default interactive entrypoint
- latest-first launcher flow that resolves and locks to one release version per session
- native Windows fast-fail messaging with a clear WSL2 Ubuntu-only support boundary
- direct subcommands for `pytools.sh`
- lightweight Bash test harness under `tests/`
- formal project docs: `CONTRIBUTING.md` and `SECURITY.md`

### Changed
- `README.md` rewritten into a more formal open-source-style project guide
- project documentation now leads with the launcher-first workflow
- pinned-version usage is now documented as an advanced/development path instead of the default path

### Verification
- `bash -n bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh tests/run.sh tests/lib/assert.sh tests/lib/test-helpers.sh`
- `bash tests/run.sh`
- `git diff --check -- README.md bfs.sh one.sh env.sh git.sh claude.sh codex.sh pytools.sh tests/run.sh tests/lib/assert.sh tests/lib/test-helpers.sh`

## Prior Releases

Structured changelog entries for earlier releases have not been backfilled yet.

For historical versions, see:
- Git tags such as `v1.3.17`, `v1.3.16`, and earlier
- `git log --decorate --oneline`
