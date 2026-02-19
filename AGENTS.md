# vpsdeploy Development Guide

This document describes the development workflow, standards, and best practices for contributing to the vpsdeploy project.

## Overview

vpsdeploy is a Bash-based deployment automation tool for provisioning VPS infrastructure. The project follows strict code quality standards and uses a story-driven development process managed through the BMAD framework (stored in `_bmad/`).

## Development Workflow

### Story-Based Development

All work is organized into stories documented in `docs/stories/`. Each story has:

- Clear description and acceptance criteria
- Dependencies on other stories
- Testing notes with reproducible test cases

**Workflow:**

1. Select a story from `docs/EPICS.md`
2. Implement changes to meet acceptance criteria
3. Test thoroughly using the provided test cases
4. Mark story as complete by checking all acceptance criteria boxes `[x]`
5. Update this guide if needed

### Epic Structure

- **Epic 1**: Core functionality - setup-vps.sh basic operations
- **Epic 2**: Deploy script enhancements - deploy.sh improvements
- **Epic 3**: Full workflow integration - end-to-end scenarios
- **Epic 4**: Error handling and recovery - resilience testing
- **Epic 5**: Maintenance and operations - backup, restore, upgrades
- **Epic 6**: Documentation and validation - completeness checks

## Code Quality Standards

The vpsdeploy project maintains strict code quality requirements:

### Bash Scripting

- **Zero shellcheck disables**: All Bash code must pass `shellcheck -x` without any `disable` comments. Fix root causes instead of suppressing warnings.
- **Exported variables**: Configuration variables are exported in `lib/config.sh` to make them visible to sourced modules.
- **Array-based command construction**: Use arrays for building commands (especially SSH) to avoid word splitting and quoting issues.
- **Syntax validation**: All scripts must pass `bash -n` syntax check.
- **Executable permissions**: Scripts must have execute permissions (`chmod +x`).

**Quick validation commands**:

```bash
# Run shellcheck on all scripts
shellcheck -x setup-vps.sh phases/*.sh lib/*.sh && echo "✅ Shellcheck passed"

# Validate syntax of all scripts
bash -n setup-vps.sh && bash -n phases/*.sh && bash -n lib/*.sh && echo "✅ All scripts have valid syntax"
```

### Testing Requirements

Before marking a story complete:

- [ ] All acceptance criteria tested and verified
- [ ] Script exits with correct exit codes (0 for success, 1 for errors)
- [ ] Error messages are clear and helpful
- [ ] Edge cases handled properly
- [ ] Idempotency verified (repeated runs should be safe)

### Commit Standards

- Write clear, descriptive commit messages
- Reference story numbers (e.g., "Story 1.1: Fix shellcheck warnings")
- Keep commits focused on a single story/feature
- Test before committing

## Project Structure

```
vpsdeploy/
├── setup-vps.sh           # Main entry point for VPS setup
├── deploy.sh              # Deployment script (legacy/alternative)
├── lib/                   # Shared library functions
│   ├── config.sh         # Configuration loading and validation
│   ├── logging.sh        # Logging utilities
│   └── ssh.sh            # SSH connection helpers
├── phases/               # Sequential execution phases
│   ├── 01_validation.sh
│   ├── 02_software.sh
│   ├── 03_firewall.sh
│   ├── 04_registry.sh
│   ├── 05_directories.sh
│   ├── 06_caddy.sh
│   ├── 07_pm2.sh
│   └── 08_summary.sh
├── docs/                 # Documentation
│   ├── stories/         # Individual story files
│   ├── EPICS.md         # Epic overview
│   ├── PRD.md           # Product requirements
│   └── manual-setup-guide.md
├── plans/               # Test plans and execution scripts
├── _bmad/               # BMAD framework (story management)
└── AGENTS.md            # This file
```

## Key Conventions

### Configuration

- Configuration loaded from `.env.deploy` in project root
- Required variables: `VPS_USER`, `VPS_IP`, `DOMAIN`, `DOMAIN_TYPE`
- For `DOMAIN_TYPE=dynamic`, `DOMAIN_PORT` is required (1024-65535)
- Optional variables have sensible defaults in `lib/config.sh`

### Domain Types

- **static**: Content is built and copied to VPS; Caddy serves static files
- **dynamic**: App runs on specified port; Caddy proxies to localhost:PORT

### Exit Codes

- `0`: Success
- `1`: Error (validation failure, command failure, etc.)

### Logging

Use the logging functions from `lib/logging.sh`:

- `log_info "message"` - Informational messages
- `log_warn "message"` - Warnings
- `log_error "message"` - Errors
- `log_success "message"` - Success indicators

### Dry Run Mode

- Use `--dry-run` flag to preview changes
- Check `$DRY_RUN` (boolean) before executing remote commands
- Log what *would* be done using `log_info "DRY RUN: Would..."`
- Never skip validation in dry-run mode

### Verbose Mode

- Use `--verbose` flag for detailed output
- Check `$VERBOSE` to show additional command output
- Pass `-v` to SSH when verbose is enabled

## Common Tasks

### Adding a New Story

1. Create file in `docs/stories/N.N-descriptive-name.md`
2. Fill in description, acceptance criteria, dependencies
3. Include testing notes with reproducible commands
4. Reference the story in `docs/EPICS.md` under appropriate epic

### Finding Incomplete Stories

To list all stories with uncompleted acceptance criteria (i.e., containing `[ ]`):

```bash
grep -l "\[ \]" docs/stories/*.md | sed 's|docs/stories/||' | sed 's|\.md||' | sort -V
```

This searches for unchecked checkboxes `[ ]` in all story files and outputs a sorted list of story IDs.

### Running Tests

```bash
# Syntax check
bash -n setup-vps.sh

# ShellCheck
shellcheck -x setup-vps.sh

# Test a story
# Follow the testing notes in the story file
```

### Updating Documentation

- Keep `README.md` in sync with changes
- Update `docs/manual-setup-guide.md` if user-facing steps change
- Update `docs/PRD.md` if product behavior changes
- Add new configuration variables to `.env.deploy.example`

## Troubleshooting

### ShellCheck SC1091 (Not following source)

This is expected when running `shellcheck setup-vps.sh` without `-x`. Always use `shellcheck -x` to include sourced files.

### Variables appear unused (SC2034)

Variables used in sourced modules appear unused in the main script. Export them after assignment:

```bash
export DRY_RUN VERBOSE SUBCOMMAND
```

### SSH connection failures

- Verify `VPS_USER`, `VPS_IP`, `SSH_PORT` in `.env.deploy`
- Test SSH manually: `ssh -p ${SSH_PORT:-22} ${VPS_USER}@${VPS_IP}`
- Check SSH key permissions and configuration

## Getting Help

- Review story testing notes for specific scenarios
- Check `./setup-vps.sh --help` for usage
- See `docs/manual-setup-guide.md` for manual setup steps
- Review `docs/EPICS.md` for overall architecture

---

**Last Updated:** 2025-02-19  
**Project:** vpsdeploy  
**Maintainer:** Luca Pescatore