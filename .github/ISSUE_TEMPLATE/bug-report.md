---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Setup VPS with `./setup-vps.sh`
2. Deploy with `./deploy.sh`
3. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Script output**
If applicable, add the script output (use `--verbose` flag for more details):

```bash
./setup-vps.sh --verbose 2>&1 | head -50
```

or

```bash
./deploy.sh --verbose 2>&1 | head -50
```

**Environment:**
- OS: [e.g. Ubuntu 22.04, macOS 14]
- Script version: [e.g. from `git log --oneline -1`]
- Domain type: [static/dynamic]
- VPS provider: [e.g. DigitalOcean, Hetzner, Linode]

**Additional context**
Add any other context about the problem here, such as:
- `.env.deploy` (redact IP/password)
- Relevant log files from VPS (`/var/log/caddy/*.log`, `pm2 logs`)
- Whether this worked before and what changed

**Checklist**
- [ ] I have read the [README.md](README.md) and [docs/manual-setup-guide.md](docs/manual-setup-guide.md)
- [ ] I have tested with `--dry-run` flag first
- [ ] I have verified my SSH connection works manually
- [ ] I have checked existing issues for duplicates
