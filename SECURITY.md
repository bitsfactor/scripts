# Security Policy

## Supported Security Boundary

This project is a collection of machine/bootstrap scripts. The highest-risk surfaces are:
- remote install URLs
- shell RC mutations
- API key handling
- SSH key handling
- package-manager execution
- trust/permission configuration

The repository currently supports:
- macOS
- Linux
- Windows through **WSL2 Ubuntu only**

Native Windows shells are out of scope for the current security and support model.

## Reporting a Vulnerability

Please avoid posting sensitive exploit details, secrets, or private key material in a public issue.

If you need to report a vulnerability:
1. gather a minimal reproduction without secrets
2. avoid publishing live credentials, private SSH keys, or sensitive host details
3. contact the maintainer through the most direct private channel you already have
4. if no private path is available, open a limited public issue with minimal detail and request a private follow-up

## What to Include

Useful security reports usually contain:
- affected script(s)
- affected platform
- exact entry command
- impact summary
- minimal reproduction steps
- whether the issue requires local access, remote access, or a malicious mirror/network path

## Secrets Handling Expectations

Never include in issues, commits, or screenshots:
- API keys
- SSH private keys
- full shell config with secrets
- real production hostnames/IPs if avoidable
- copied token-bearing command histories

## Maintainer Guidance

When handling a reported issue:
- confirm scope first
- rotate any accidentally exposed secrets immediately
- prefer narrow fixes over broad rewrites
- re-run syntax and test verification after the patch
- document user-facing mitigation in `README.md` when the behavior changed

## Hardening Expectations for Changes

Security-sensitive changes should be reviewed especially carefully when they touch:
- `curl | bash` flows
- `CDN_BASE` / remote URL composition
- shell RC file writes
- SSH key generation / installation
- API credential persistence
- permission bypass or trust-all settings
