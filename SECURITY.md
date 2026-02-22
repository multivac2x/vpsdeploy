# Security Policy

## Supported Versions

vps-deploy is actively maintained. Security updates are applied to the latest version on the `main` branch.

| Version | Supported          |
| ------- | ------------------ |
| < 1.0   | :x: Not supported  |
| 1.0+    | :white_check_mark: Supported |

## Reporting a Vulnerability

We take the security of vps-deploy seriously. If you believe you have found a security vulnerability, please report it to us privately before disclosing it publicly.

### How to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead, please email the maintainer directly at:

**luca@pescatore.it** (replace with actual email if different)

Please include:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes or mitigations

### What to Expect

- **Initial Response**: We aim to acknowledge receipt within 48 hours.
- **Assessment**: We will investigate and determine severity.
- **Fix Timeline**: Critical issues will be addressed as soon as possible; less severe issues will be scheduled for a future release.
- **Coordination**: We may ask for additional information or testing.
- **Disclosure**: Once a fix is ready, we will coordinate a public disclosure. We request that you keep the vulnerability confidential until we have published a fix.

## Security Best Practices for Users

### SSH Key Security

- Use strong SSH keys (ed25519 or RSA 4096)
- Protect private keys with a passphrase
- Never commit SSH private keys to version control
- Use separate deploy keys per project/VPS

### VPS Configuration

- Create a dedicated non-root deploy user with sudo privileges
- Disable password authentication for SSH
- Use a non-standard SSH port (optional but recommended)
- Keep the system updated: `sudo apt update && sudo apt upgrade`
- Configure UFW firewall to allow only necessary ports (22, 80, 443)

### Environment File

- `.env.deploy` contains sensitive information (VPS IP, user, etc.)
- Add `.env.deploy` to `.gitignore` (already configured)
- Never commit `.env.deploy` to version control
- Use `.env.deploy.example` as a template with placeholder values
- Set restrictive permissions: `chmod 600 .env.deploy`

### Domain and SSL

- Use valid domain names that point to your VPS
- Let Caddy handle SSL certificate automation
- Monitor certificate renewal: `sudo caddy list-certificates`
- Certificates auto-renew via Let's Encrypt

### Script Execution

- Only run scripts from trusted sources
- Review scripts before execution, especially if modified
- Use `--dry-run` flag first to preview changes
- Verify checksums/signatures if distributing binaries

## Known Security Considerations

### Bash Scripts

- The scripts use `set -euo pipefail` for strict error handling
- All remote commands use SSH with key-based authentication
- No passwords are stored or transmitted in plaintext
- Temporary files are created with `mktemp` and cleaned up

### File Permissions

- Scripts are executable (`chmod +x`)
- Configuration files should be readable only by owner (`chmod 600`)
- Registry file `/etc/caddy/domains.json` is owned by root with 644 permissions

### Network Security

- All communications use SSH (encrypted)
- Caddy automatically provisions and renews SSL certificates
- UFW firewall restricts inbound traffic to necessary ports only

## Security Updates

Security updates will be released as new versions. We recommend:

1. Subscribe to releases on GitHub
2. Pull updates regularly: `git pull origin main`
3. Review changes before applying
4. Test in a staging environment if possible

## Third-Party Dependencies

The scripts depend on:

- **Caddy**: Automatically obtained from official Cloudflare repository
- **Node.js/PM2**: Installed from NodeSource (if needed)
- **jq**: Installed from Ubuntu repositories

Always verify package sources and GPG keys during installation.

## Responsible Disclosure

We follow responsible disclosure practices:

1. Reporter gives vendor (us) reasonable time to fix (typically 90 days)
2. Fix is developed and tested
3. Coordinated public disclosure with CVE assignment if applicable
4. Release notes include security fix details

We appreciate the work of security researchers and will acknowledge contributions in our release notes (unless anonymity is requested).

## Contact

For security issues: **luca@pescatore.it** (replace with actual email)

For general questions: Use GitHub issues or discussions.
