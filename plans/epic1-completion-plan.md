# Epic 1 Completion Plan: Stories 1.21-1.37

## Overview

This plan outlines the implementation strategy for completing the remaining 17 stories in Epic 1. The stories are grouped by functional area and ordered by dependencies.

**Total Remaining Stories:** 17 (1.21 through 1.37)
**Estimated Complexity:** Varies from simple verification to new feature implementation

---

## Story Analysis and Implementation Plan

### Group 1: PM2 and Summary (Stories 1.21-1.24)

These stories build on the existing PM2 phase and summary functionality.

#### Story 1.21: PM2 Setup - Dynamic Domain with App Code
**Status:** Partially Implemented - Needs Verification
**Current Implementation:** [`phases/07_pm2.sh`](phases/07_pm2.sh:1) lines 27-39 deploy app code and start PM2
**Acceptance Criteria to Verify:**
- [ ] `package.json` exists check - Currently checks local package.json (line 16), but should also verify remote app directory
- [ ] PM2 restart vs start logic - Currently always uses `pm2 start`, should check if process exists first
- [ ] `pm2 startup` configured detection - Currently always runs `pm2 startup`, should check if already enabled
- [ ] PM2 process status "online" verification - Not explicitly verified after start

**Required Changes:**
1. Modify PM2 start logic to restart if process exists:
   ```bash
   if ssh_run "pm2 jlist | jq -r --arg name '$PM2_APP_NAME' '.[] | select(.name == \$name) | .name'" 2>/dev/null | grep -q "$PM2_APP_NAME"; then
       ssh_run "pm2 restart $PM2_APP_NAME"
   else
       ssh_run "pm2 start $BUILD_CMD --name $PM2_APP_NAME"
   fi
   ```
2. Check if pm2 startup is already enabled before configuring:
   ```bash
   if ! ssh_run "systemctl is-enabled pm2-${VPS_USER}" &>/dev/null; then
       ssh_run "pm2 startup systemd -u ${VPS_USER} --hp /home/${VPS_USER}"
   fi
   ```
3. Verify process is online after setup

#### Story 1.22: PM2 Setup - Dynamic Domain without App Code
**Status:** Partially Implemented - Needs Verification
**Current Implementation:** [`phases/07_pm2.sh`](phases/07_pm2.sh:1) lines 16-20 skip if no local package.json
**Acceptance Criteria to Verify:**
- [ ] If package.json does NOT exist - Currently checks local package.json, but should also consider if app hasn't been deployed yet
- [ ] PM2 start is skipped - Already implemented (returns early)
- [ ] Reminder message printed - Current message (line 18-19) needs to be more specific with actual command
- [ ] `pm2 save` still executed - Currently skipped when no package.json, should still execute
- [ ] `pm2 startup` configured if needed - Currently skipped when no package.json, should still configure

**Required Changes:**
1. Modify to still run `pm2 save` and `pm2 startup` even without app code:
   ```bash
   if [[ ! -f "package.json" ]]; then
       log_warn "No local package.json found. App code not deployed yet."
       log_info "After deploying app, manually run: pm2 start npm --name '$DOMAIN' -- start"
       # Still configure pm2 startup
       if ! ssh_run "systemctl is-enabled pm2-${VPS_USER}" &>/dev/null; then
           log_info "Configuring PM2 startup..."
           ssh_run "pm2 startup systemd -u ${VPS_USER} --hp /home/${VPS_USER}"
       fi
       ssh_run "pm2 save" 2>/dev/null || true
       return
   fi
   ```

#### Story 1.23: Summary Status Table - All Domains
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/08_summary.sh`](phases/08_summary.sh:1) lines 11-52 display status table
**Acceptance Criteria to Verify:**
- [ ] Table shows all domains from registry - Implemented (line 24-52)
- [ ] Columns: Domain, Type, Port, Status - Implemented (line 15)
- [ ] Static domain status: ✅ if index.html exists, ⚠️ if missing - Currently checks if web root has files (line 33-37), should specifically check for index.html
- [ ] Dynamic domain status: ✅ if PM2 online, ❌ if stopped/errored, ⚠️ if no process - Implemented (lines 39-49)
- [ ] Table formatted with borders - Implemented (lines 12-16)
- [ ] VPS IP displayed in header - Not implemented, need to add VPS IP to header

**Required Changes:**
1. Update static status check to look for index.html specifically:
   ```bash
   if ssh_run "test -f /var/www/$domain/index.html" &>/dev/null; then
       status="${GREEN}✅ Caddy OK${NC}"
   elif ssh_run "test -n \$(ls -A /var/www/$domain 2>/dev/null)" &>/dev/null; then
       status="${YELLOW}⚠️  No index.html${NC}"
   else
       status="${YELLOW}⚠️  Empty${NC}"
   fi
   ```
2. Add VPS IP to header (line 13):
   ```bash
   echo -e "  🖥  VPS Domain Status ($VPS_IP)"
   ```

#### Story 1.24: Status Subcommand
**Status:** Implemented - Needs Verification
**Current Implementation:** [`setup-vps.sh`](setup-vps.sh:1) lines 127-130 and [`phases/08_summary.sh`](phases/08_summary.sh:1) lines 77-81
**Acceptance Criteria to Verify:**
- [ ] `./setup-vps.sh status` connects and reads registry - Implemented
- [ ] Displays status table - Implemented via phase8_summary
- [ ] Checks Caddy: domain in active Caddyfile - Not implemented, need to add check
- [ ] Checks Static: web root contains files - Already in summary
- [ ] Checks Dynamic: PM2 process running - Already in summary
- [ ] Checks SSL: curl returns 200 - Not implemented, need to add SSL check
- [ ] Displays Caddy service status - Implemented (line 62-63)
- [ ] Displays disk usage and memory - Implemented (lines 66-73)
- [ ] No changes made (read-only) - Status subcommand only calls phase1_validation and phase8_summary, both read-only ✓
- [ ] Exit code 0 - Implemented (line 80)

**Required Changes:**
1. Enhance status table to include SSL check for each domain:
   ```bash
   # After determining type/port/status, add SSL check
   local ssl_status=""
   if ssh_run "curl -sI https://$domain 2>/dev/null | head -1 | grep -q '200 OK'" &>/dev/null; then
       ssl_status="${GREEN}🔒${NC}"
   else
       ssl_status="${RED}❓${NC}"
   fi
   # Modify printf to include SSL status
   ```
2. Add check that domain is in Caddyfile:
   ```bash
   if ssh_run "sudo grep -q '$domain' /etc/caddy/Caddyfile" &>/dev/null; then
       # domain in caddyfile
   else
       # domain not in caddyfile (should not happen)
   fi
   ```

---

### Group 2: Remove Subcommand (Stories 1.25-1.26)

#### Story 1.25: Remove Subcommand - Confirmation
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/08_summary.sh`](phases/08_summary.sh:1) lines 83-117 (cmd_remove)
**Acceptance Criteria to Verify:**
- [ ] `./setup-vps.sh remove` reads `.env.deploy` to get `DOMAIN` - Implemented (line 86)
- [ ] If domain not in registry, logs message and exits code 0 - Implemented (lines 94-96)
- [ ] Prints what will be removed - Implemented (lines 101-110)
- [ ] Prompts for confirmation - Implemented (line 113)
- [ ] Non-y input aborts - Implemented (lines 114-117)
- [ ] Confirmed 'y' proceeds - Implemented (continues after line 117)

**No changes needed - already implemented correctly.**

#### Story 1.26: Remove Subcommand - Execution
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/08_summary.sh`](phases/08_summary.sh:1) lines 119-175
**Acceptance Criteria to Verify:**
- [ ] Domain removed from `/etc/caddy/domains.json` - Implemented (lines 120-126)
- [ ] If dynamic: PM2 process stopped/deleted - Implemented (lines 128-136)
- [ ] Caddyfile regenerated - Implemented (lines 138-141)
- [ ] Caddy reloaded - Implemented (lines 154-156)
- [ ] `pm2 save` executed - Implemented (line 133)
- [ ] Reminder printed about files NOT deleted - Implemented (lines 170-174)
- [ ] Domain no longer accessible - Should be verified via DNS/Caddy

**No changes needed - already implemented correctly.**

---

### Group 3: Resilience and Recovery (Stories 1.27-1.30)

#### Story 1.27: Idempotency - Repeated Runs
**Status:** Needs Implementation
**Current Implementation:** Not explicitly tested/verified
**Acceptance Criteria:**
- [ ] First run completes successfully - Should work with current code
- [ ] Second run identical: no errors, registry unchanged, Caddyfile identical, Caddy not reloaded - Need to verify diff check works (Story 1.18)
- [ ] Third run identical to second - Should work

**Required Changes:**
1. Ensure phase6_caddy.sh diff check is robust (already implemented in Story 1.18)
2. Verify that registry updates are idempotent (timestamps may update but structure same)
3. Add test case to verify repeated runs produce identical output

**Implementation:** No code changes needed, but should be verified through testing.

#### Story 1.28: SSH Connection Failure
**Status:** Partially Implemented - Needs Enhancement
**Current Implementation:** [`phases/01_validation.sh`](phases/01_validation.sh:1) needs to be checked
**Acceptance Criteria:**
- [ ] With invalid VPS_IP or SSH down - Need to test connection early
- [ ] Script attempts SSH with timeout (10s) and batch mode - Already in [`lib/ssh.sh`](lib/ssh.sh:1) build_ssh_opts (ConnectTimeout=10, BatchMode=yes)
- [ ] On failure exits with code 1 - Need to ensure early check fails properly
- [ ] Error message: "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}" - Need to implement
- [ ] Suggests checking: SSH key, VPS_USER, VPS_IP, SSH_PORT - Need to implement
- [ ] No partial changes made - Need early check before any modifications

**Required Changes:**
1. In [`phases/01_validation.sh`](phases/01_validation.sh:1), add early SSH connectivity test:
   ```bash
   log_info "Testing SSH connection to ${VPS_USER}@${VPS_IP}:${SSH_PORT}..."
   if ! ssh_run "echo ok" &>/dev/null; then
       log_error "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
       log_info "Please check:"
       log_info "  - SSH key is properly set up"
       log_info "  - VPS_USER is correct"
       log_info "  - VPS_IP is reachable"
       log_info "  - SSH_PORT is correct"
       exit 1
   fi
   ```
2. Ensure this check runs BEFORE any phase that makes changes
3. In dry-run mode, skip actual connection but still validate parameters

#### Story 1.29: Registry Corruption Recovery
**Status:** Needs Implementation
**Current Implementation:** Not implemented
**Acceptance Criteria:**
- [ ] If registry file missing: creates fresh empty registry with version 1 and empty domains object
- [ ] If registry contains invalid JSON: backs up corrupted file, creates fresh registry, logs warning, continues
- [ ] Current domain is then added to fresh registry

**Required Changes:**
1. In phase4_registry.sh (or a new function), modify registry loading:
   ```bash
   load_registry() {
       local registry_path="/etc/caddy/domains.json"
       
       if ! ssh_run "test -f $registry_path" &>/dev/null; then
           log_info "Registry not found, creating fresh one..."
           echo '{"version":1,"domains":{}}' | ssh_run "sudo tee $registry_path > /dev/null"
           return 0
       fi
       
       # Validate JSON
       if ! ssh_run "sudo cat $registry_path" | jq . &>/dev/null; then
           log_warn "Registry contains invalid JSON! Backing up..."
           local timestamp=$(date +%Y%m%d_%H%M%S)
           ssh_run "sudo cp $registry_path ${registry_path}.corrupt.${timestamp}"
           log_info "Corrupted registry backed up to ${registry_path}.corrupt.${timestamp}"
           log_info "Creating fresh registry..."
           echo '{"version":1,"domains":{}}' | ssh_run "sudo tee $registry_path > /dev/null"
       fi
   }
   ```
2. Call this function at the start of phase4_registry

#### Story 1.30: Caddy Validation Failure Recovery
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/06_caddy.sh`](phases/06_caddy.sh:1) and [`phases/08_summary.sh`](phases/08_summary.sh:1) lines 154-163
**Acceptance Criteria:**
- [ ] Simulate invalid Caddyfile (corrupt registry) - Can test via Story 1.29
- [ ] Script attempts `caddy validate` after generation - Implemented in phase6_caddy (need to check) and cmd_remove (lines 154-156)
- [ ] On validation failure: backup saved, previous restored, Caddy NOT reloaded, error logged, exit 1 - Implemented in cmd_remove (lines 158-162), need to verify phase6_caddy has same logic
- [ ] VPS remains functional with previous configuration - Implemented via restore

**Required Changes:**
1. Ensure phase6_caddy.sh has identical backup/restore logic as cmd_remove
2. Verify that on validation failure, old Caddyfile is restored and Caddy is NOT reloaded

---

### Group 4: Domain Type Changes (Stories 1.31-1.32)

#### Story 1.31: Domain Type Change - Static to Dynamic
**Status:** Needs Implementation
**Current Implementation:** Not implemented - registry update doesn't handle type changes
**Acceptance Criteria:**
- [ ] Domain exists as static in registry - Starting state
- [ ] Update `.env.deploy` to `DOMAIN_TYPE=dynamic` with valid port - User action
- [ ] Run `setup-vps.sh` - Triggers registry update
- [ ] Registry entry updated to dynamic with port - Need to implement
- [ ] Dynamic app directory created at `${VPS_APPS_PATH}/${DOMAIN}` - Need to implement
- [ ] Caddyfile regenerated with `reverse_proxy` - Should work via generate_caddyfile
- [ ] Caddy reloaded - Already implemented
- [ ] Logs message about type change - Need to implement
- [ ] Static directory at `/var/www/${DOMAIN}` is NOT automatically deleted - Should not delete

**Required Changes:**
1. In phase4_registry.sh, when updating existing domain entry, detect type change:
   ```bash
   local existing_type
   existing_type=$(echo "$registry_content" | jq -r --arg d "$DOMAIN" '.domains[$d].type // empty')
   if [[ -n "$existing_type" ]] && [[ "$existing_type" != "$DOMAIN_TYPE" ]]; then
       log_info "Domain type changing from $existing_type to $DOMAIN_TYPE"
       # Type change detected - handle specially
   fi
   ```
2. When changing static→dynamic:
   - Update registry entry with type="dynamic" and port field
   - Create app directory (phase5_directories should handle this based on DOMAIN_TYPE)
   - Do NOT delete static directory
3. Add logging: "Domain $DOMAIN type changed from static to dynamic"

#### Story 1.32: Domain Type Change - Dynamic to Static
**Status:** Needs Implementation
**Current Implementation:** Not implemented - registry update doesn't handle type changes
**Acceptance Criteria:**
- [ ] Domain exists as dynamic in registry
- [ ] Update `.env.deploy` to `DOMAIN_TYPE=static` (remove port)
- [ ] Run `setup-vps.sh`
- [ ] Registry updated to static (port removed)
- [ ] Static web root created at `${VPS_BASE_PATH}/${DOMAIN}`
- [ ] Caddyfile regenerated with `file_server`
- [ ] Caddy reloaded
- [ ] PM2 process for domain is stopped and deleted
- [ ] `pm2 save` executed
- [ ] Logs message about type change and PM2 removal
- [ ] Dynamic app directory at `/home/deploy/apps/${DOMAIN}` is NOT automatically deleted

**Required Changes:**
1. In phase4_registry.sh, handle dynamic→static type change:
   ```bash
   if [[ "$existing_type" == "dynamic" ]] && [[ "$DOMAIN_TYPE" == "static" ]]; then
       log_info "Domain type changing from dynamic to static"
       # Stop and delete PM2 process
       if [[ "$DRY_RUN" == false ]]; then
           ssh_run "pm2 delete $DOMAIN 2>/dev/null || true"
           ssh_run "pm2 save"
           log_info "PM2 process for $DOMAIN stopped and deleted"
       fi
       # Remove port from registry entry
   fi
   ```
2. Create static directory in phase5_directories (already should work)
3. Log appropriate messages

---

### Group 5: Software Installation (Stories 1.33-1.35)

#### Story 1.33: Software Installation - Caddy
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/02_software.sh`](phases/02_software.sh:1) lines 18-30
**Acceptance Criteria:**
- [ ] On fresh VPS with no Caddy: script installs via official apt repository - Implemented
- [ ] Commands executed: add GPG key, add repo, apt update, apt install - Implemented (lines 25-28)
- [ ] After install, `caddy version` succeeds - Checked via command -v and version logged
- [ ] Caddy service enabled and running - Not explicitly checked/enabled
- [ ] On subsequent runs, installation is skipped and version is logged - Implemented (line 19-22)

**Required Changes:**
1. Ensure Caddy service is enabled after installation:
   ```bash
   ssh_run "sudo systemctl enable caddy"
   ssh_run "sudo systemctl start caddy"
   ```
2. Verify service is active: `ssh_run "systemctl is-active caddy"`

#### Story 1.34: Software Installation - jq
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/02_software.sh`](phases/02_software.sh:1) lines 7-16
**Acceptance Criteria:**
- [ ] If `jq --version` fails, script installs via `sudo apt install -y jq` - Implemented
- [ ] After install, `jq --version` succeeds - Verified
- [ ] jq is available for registry manipulation - Yes

**No changes needed.**

#### Story 1.35: Software Installation - Node.js and PM2 (Conditional)
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/02_software.sh`](phases/02_software.sh:1) lines 32-73
**Acceptance Criteria:**
- [ ] Fresh VPS, first domain is static: Node.js and PM2 are NOT installed - Implemented (checks dynamic_count and DOMAIN_TYPE)
- [ ] Second domain is dynamic: script detects existing dynamic domain in registry - Implemented (line 38 checks registry for dynamic domains)
- [ ] Node.js installed via nvm (latest LTS) for deploy user - Implemented (lines 55-58)
- [ ] PM2 installed globally via npm - Implemented (lines 67-70)
- [ ] `pm2 startup` configured for deploy user - Not explicitly configured in phase2, only in phase7_pm2
- [ ] If registry already has dynamic domains, new static domain run does NOT uninstall Node.js/PM2 - Implemented (needs_node_pm2 remains true if dynamic domains exist)

**Required Changes:**
1. Move `pm2 startup` configuration to phase2 when Node.js/PM2 are installed:
   ```bash
   ssh_run "pm2 startup systemd -u ${VPS_USER} --hp /home/${VPS_USER}" 2>/dev/null || true
   ```
2. Ensure this only runs once (check if already enabled)

---

### Group 6: Firewall and Verbose Mode (Stories 1.36-1.37)

#### Story 1.36: Firewall Configuration - UFW
**Status:** Implemented - Needs Verification
**Current Implementation:** [`phases/03_firewall.sh`](phases/03_firewall.sh:1)
**Acceptance Criteria:**
- [ ] Script checks if UFW is active - Implemented (line 29)
- [ ] Ensures rules exist for ports: 22, 80, 443 - Implemented (lines 17-21)
- [ ] If rules missing, adds them - Implemented (each `ufw allow` is idempotent)
- [ ] If UFW is inactive, enables it with `--force` after ensuring SSH rule - Implemented (lines 29-32)
- [ ] Final status shows rules in order: 22, 80, 443 - UFW maintains order
- [ ] Default deny policy in place (if UFW was fresh) - Default UFW policy is deny incoming

**No changes needed - already implemented correctly.**

#### Story 1.37: Verbose Mode
**Status:** Implemented - Needs Verification
**Current Implementation:** [`setup-vps.sh`](setup-vps.sh:1) parse_arguments, [`lib/ssh.sh`](lib/ssh.sh:1) build_ssh_opts
**Acceptance Criteria:**
- [ ] With `--verbose`, script shows stdout/stderr from remote commands - Implemented via SSH `-v` flag (line 8 in ssh.sh)
- [ ] Without `--verbose`, remote command output is suppressed - Implemented (ssh_run only shows DRY RUN message, not command output)
- [ ] Verbose mode works with all subcommands (setup, status, remove) - Should work globally via VERBOSE variable
- [ ] Can be combined with `--dry-run` - Implemented

**Note:** Current implementation only shows SSH debug output with `-v`, but doesn't show remote command stdout/stderr. May need adjustment based on story intent.

**Required Changes:**
1. In `ssh_run()`, when VERBOSE=true, capture and display remote command output:
   ```bash
   if [[ "$VERBOSE" == true ]]; then
       ssh "${cmd[@]}" 2>&1 | while IFS= read -r line; do
           log_info "REMOTE: $line"
       done
   else
       ssh "${cmd[@]}" 2>/dev/null
   fi
   ```
   Or simpler: `ssh "${cmd[@]}"` without suppressing output when verbose.

---

## Implementation Priority and Order

### Phase 1: Critical Gaps (Must Implement First)
1. **Story 1.28** - SSH connection failure handling (early validation)
2. **Story 1.29** - Registry corruption recovery
3. **Story 1.30** - Caddy validation failure recovery in phase6 (verify/complete)
4. **Story 1.31** - Static to dynamic type change
5. **Story 1.32** - Dynamic to static type change

### Phase 2: PM2 and Summary Enhancements
6. **Story 1.21** - PM2 with app code (restart logic, startup check)
7. **Story 1.22** - PM2 without app code (save/startup even without code)
8. **Story 1.23** - Summary table enhancements (index.html check, VPS IP)
9. **Story 1.24** - Status subcommand enhancements (SSL check, Caddyfile check)

### Phase 3: Software Installation Polish
10. **Story 1.33** - Verify Caddy service enablement
11. **Story 1.35** - Move pm2 startup to phase2

### Phase 4: Verification and Testing
12. **Story 1.27** - Idempotency (test, not implement)
13. **Story 1.34** - Verify jq installation (test)
14. **Story 1.36** - Verify UFW (test)
15. **Story 1.37** - Verbose mode (adjust if needed)

---

## Detailed Implementation Steps

### Step 1: Enhance SSH Connection Validation (Story 1.28)
- Modify [`phases/01_validation.sh`](phases/01_validation.sh:1) to add early connectivity test
- Ensure proper error messages and suggestions
- Respect dry-run mode (skip actual connection but validate config)

### Step 2: Add Registry Corruption Recovery (Story 1.29)
- Create `load_registry()` function in [`phases/04_registry.sh`](phases/04_registry.sh:1)
- Handle missing file: create fresh registry
- Handle invalid JSON: backup corrupted file, create fresh registry
- Call this function at the start of phase4

### Step 3: Complete Caddy Validation Recovery (Story 1.30)
- Review [`phases/06_caddy.sh`](phases/06_caddy.sh:1) to ensure backup/restore logic matches [`phases/08_summary.sh`](phases/08_summary.sh:1) lines 154-162
- Add missing backup/restore if not present
- Ensure exit code 1 on failure

### Step 4: Implement Domain Type Changes (Stories 1.31-1.32)
- Modify [`phases/04_registry.sh`](phases/04_registry.sh:1) to detect type changes by comparing existing registry entry with current `$DOMAIN_TYPE`
- For static→dynamic: add port field, create app directory, log change
- For dynamic→static: remove port field, stop/delete PM2, create static directory, log change
- Ensure both cases preserve existing data (don't delete old directories)

### Step 5: Enhance PM2 Setup (Stories 1.21-1.22)
- Modify [`phases/07_pm2.sh`](phases/07_pm2.sh:1):
  - Check if PM2 process exists before starting (restart vs start)
  - Check if pm2 startup already enabled before configuring
  - Verify process is online after start
  - For no app code: still run `pm2 save` and `pm2 startup`, provide clear manual command
- Update reminder message to be more actionable

### Step 6: Enhance Summary and Status (Stories 1.23-1.24)
- Modify [`phases/08_summary.sh`](phases/08_summary.sh:1):
  - Check for `index.html` specifically for static domains
  - Add VPS IP to header
  - Add SSL check for each domain (curl -sI)
  - Add check that domain is in Caddyfile
- Update `cmd_status` to include all checks

### Step 7: Polish Software Installation (Stories 1.33, 1.35)
- In [`phases/02_software.sh`](phases/02_software.sh:1):
  - After installing Caddy, enable and start the service
  - After installing Node.js/PM2, configure `pm2 startup` (if not already done)
- Ensure these operations are idempotent

### Step 8: Verbose Mode Enhancement (Story 1.37)
- Review [`lib/ssh.sh`](lib/ssh.sh:1) `ssh_run()` function
- When VERBOSE=true, show full remote command output (not just DRY RUN messages)
- Ensure works with all subcommands

### Step 9: Testing and Verification
- For each story, run the testing notes from the story files
- Verify all acceptance criteria are met
- Mark stories as complete by updating checkbox from `[ ]` to `[x]` in story files
- Run shellcheck and syntax validation

---

## Dependencies Map

```
1.28 (SSH failure) → All others (must be first)
1.29 (registry corruption) → 1.31, 1.32 (type changes need registry loading)
1.30 (validation recovery) → 1.31, 1.32 (type changes regenerate Caddyfile)
1.31 (static→dynamic) → 1.21, 1.22 (PM2 setup for dynamic)
1.32 (dynamic→static) → 1.21, 1.22 (PM2 cleanup)
1.21, 1.22 → 1.23, 1.24 (summary/status need PM2 status)
1.23, 1.24 → 1.27 (idempotency testing needs stable summary)
```

---

## Success Criteria

- All 17 stories (1.21-1.37) have all acceptance criteria checked `[x]`
- All scripts pass `shellcheck -x` with no warnings
- All scripts pass `bash -n` syntax check
- No regressions in already-completed stories (1.1-1.20)
- Code follows project standards: `set -euo pipefail`, exported variables, array-based SSH commands

---

## Notes

- Stories 1.27 (idempotency), 1.34 (jq), and 1.36 (UFW) are largely already implemented and primarily require verification/testing.
- Stories 1.21-1.24 require careful coordination between phases to ensure proper state management.
- Type change stories (1.31-1.32) are the most complex as they involve multiple components (registry, directories, Caddyfile, PM2).
- Remember to update story files with `[x]` checkmarks upon completion.
- Maintain backward compatibility - existing domains should continue to work without modification.
