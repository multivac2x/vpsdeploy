# Implementation Plan: Stories 1.7-1.20

## Current Status Analysis

### Already Implemented (Needs Verification)
- **1.7, 1.8**: Dry-run mode functionality exists
- **1.9**: Phase execution order is defined in setup-vps.sh main()
- **1.10**: Registry creation implemented in phase4_registry
- **1.11**: Registry merge implemented via jq in phase4_registry
- **1.12**: Registry update implemented (preserves added_at)
- **1.13**: Port conflict detection implemented (lines 90-97 in phase4_registry)
- **1.14, 1.15**: Caddyfile generation implemented in generate_caddyfile()
- **1.16**: Domains sorted alphabetically (jq `sort[]`)
- **1.17**: Caddyfile backup and validation implemented
- **1.19**: Directory setup for static domains implemented
- **1.20**: Directory setup for dynamic domains implemented (but missing Caddy log dir setup)

### Needs Implementation
- **1.18**: Caddy reload only on config changes - currently always reloads

### Missing Features to Verify

1. **Story 1.14 (Static Caddyfile)**: Check for static asset caching headers - need to verify these are in generate_caddyfile
2. **Story 1.15 (Dynamic Caddyfile)**: Verify no root/file_server directives for dynamic
3. **Story 1.20**: Caddy log directory `/var/log/caddy/` needs to be created with proper permissions (www-data writable)
4. **Story 1.17**: Need to verify that on validation failure, backup is restored

## Implementation Tasks

### Task 1: Fix Story 1.18 - Conditional Caddy Reload
**File**: `phases/06_caddy.sh`

Currently, Caddy is always reloaded. Need to:
- Compare new Caddyfile with existing before writing
- Only write, validate, and reload if changes detected
- Log "No Caddy config changes" if identical

**Approach**:
- Before writing, compute diff between new_caddyfile and existing Caddyfile
- If no differences, skip backup/write/validate/reload
- If differences exist, proceed with current logic

### Task 2: Create Caddy Log Directory
**File**: `phases/05_directories.sh` or `phases/06_caddy.sh`

Add creation of `/var/log/caddy/` with proper ownership (www-data:www-data) and permissions.

**Location**: Best placed in phase5_directories or as part of phase6_caddy before writing logs.

### Task 3: Verify Static Asset Caching
**File**: `phases/04_registry.sh` (generate_caddyfile function)

Check that the static domain configuration includes caching headers for CSS/JS/images/fonts as specified in story 1.14.

**Current code** (lines 43-44):
```bash
@static path *.css *.js *.png *.jpg *.jpeg *.gif *.svg *.woff *.woff2 *.ico
header @static Cache-Control "public, max-age=31536000, immutable"
```

This appears to already be implemented. Need to verify.

### Task 4: Verify Dynamic Domain Configuration
**File**: `phases/04_registry.sh`

Ensure dynamic domains do NOT have `root` or `file_server` directives. Current code (lines 37-39) uses only `reverse_proxy` - correct.

### Task 5: Test All Stories
After implementing fixes, run test cases from each story to verify acceptance criteria.

## Execution Order

1. Implement Task 1 (Story 1.18) - conditional reload
2. Implement Task 2 (Story 1.20) - caddy log directory
3. Verify Tasks 3 & 4 are already correct
4. Test stories 1.7-1.20 systematically
5. Mark stories complete in documentation

## Dependencies

- Story 1.18 depends on 1.17 (backup/validation)
- Stories 1.10-1.12, 1.14-1.16, 1.19-1.20 all depend on actual execution, which requires a VPS or mocking
- For testing without a VPS, we can use dry-run to verify logic, but some stories require actual execution

## Notes

- The project uses `set -euo pipefail` so errors will cause exit
- All changes must pass `shellcheck -x` and `bash -n`
- When marking stories complete, update the checkboxes in `docs/stories/*.md`
- Keep AGENTS.md updated with any new best practices
