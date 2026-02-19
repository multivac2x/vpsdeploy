# Epics and Stories for Testing and Deployment

Based on the PRD and existing test plan, here are the comprehensive epics and stories organized by functional area.

---

## Epic 1: setup-vps.sh Core Functionality Testing

### Story 1.1: Script Syntax and Static Analysis
**Description:** Verify that `setup-vps.sh` passes basic syntax and quality checks before any functional testing.

**Acceptance Criteria:**
- [ ] `bash -n setup-vps.sh` exits with code 0 (no syntax errors)
- [ ] `shellcheck setup-vps.sh` produces no warnings or errors (if shellcheck available)
- [ ] Script has proper shebang and executable permissions

**Dependencies:** None
**Priority:** Must-have (blocker for all other tests)

---

### Story 1.2: Help and Usage Display
**Description:** Ensure the script displays proper help information and handles invalid options gracefully.

**Acceptance Criteria:**
- [ ] `./setup-vps.sh --help` displays usage information with examples
- [ ] `./setup-vps.sh --help` exits with code 0
- [ ] `./setup-vps.sh --invalid-option` displays error message and exits with code 1
- [ ] Help text includes all subcommands (setup, status, remove) and flags (--dry-run, --verbose)

**Dependencies:** Story 1.1
**Priority:** Must-have

---

### Story 1.3: Configuration Validation - Missing .env.deploy
**Description:** Script should detect missing configuration file and provide clear guidance.

**Acceptance Criteria:**
- [ ] When `.env.deploy` does not exist, script exits with code 1
- [ ] Error message clearly states that `.env.deploy` is missing
- [ ] Error message includes template showing required variables
- [ ] No remote commands are executed when config is missing

**Dependencies:** Story 1.1
**Priority:** Must-have

---

### Story 1.4: Configuration Validation - Invalid DOMAIN_TYPE
**Description:** Validate that `DOMAIN_TYPE` must be either `static` or `dynamic`.

**Acceptance Criteria:**
- [ ] With `DOMAIN_TYPE=invalid`, script exits with code 1
- [ ] Error message: "DOMAIN_TYPE must be 'static' or 'dynamic'"
- [ ] No remote commands executed

**Dependencies:** Story 1.1
**Priority:** Must-have

---

### Story 1.5: Configuration Validation - Missing DOMAIN_PORT for Dynamic
**Description:** Ensure `DOMAIN_PORT` is required when `DOMAIN_TYPE=dynamic`.

**Acceptance Criteria:**
- [ ] With `DOMAIN_TYPE=dynamic` and no `DOMAIN_PORT`, script exits with code 1
- [ ] Error message: "DOMAIN_PORT is required for dynamic domains"
- [ ] With `DOMAIN_TYPE=static` and `DOMAIN_PORT` set, script proceeds (port is ignored)

**Dependencies:** Story 1.1
**Priority:** Must-have

---

### Story 1.6: Configuration Validation - Invalid DOMAIN_PORT
**Description:** Validate port number range and format.

**Acceptance Criteria:**
- [ ] Port < 1024 or > 65535 → error "DOMAIN_PORT must be an integer between 1024 and 65535", exit code 1
- [ ] Non-numeric port → error about port validation, exit code 1
- [ ] Port at boundaries (1024, 65535) → accepted and proceed
- [ ] Port within valid range (e.g., 3000) → accepted

**Dependencies:** Story 1.1
**Priority:** Must-have

---

### Story 1.7: Dry-Run Mode - Static Domain
**Description:** Verify dry-run mode shows all intended actions without making changes for static domains.

**Acceptance Criteria:**
- [ ] `./setup-vps.sh --dry-run --verbose` outputs all commands that would be executed
- [ ] No actual changes are made to VPS (no SSH commands executed)
- [ ] Output includes: validation, software installation checks, registry update preview, directory creation, Caddyfile generation preview
- [ ] Exit code is 0 if validation passes

**Dependencies:** Stories 1.3-1.6
**Priority:** Must-have

---

### Story 1.8: Dry-Run Mode - Dynamic Domain
**Description:** Verify dry-run mode includes Node.js/PM2 installation and setup for dynamic domains.

**Acceptance Criteria:**
- [ ] `./setup-vps.sh --dry-run --verbose` with `DOMAIN_TYPE=dynamic` shows Node.js/PM2 installation checks
- [ ] Shows PM2 setup phase
- [ ] Shows port conflict check
- [ ] No actual changes made, exit code 0 if validation passes

**Dependencies:** Stories 1.1-1.6
**Priority:** Must-have

---

### Story 1.9: Phase Execution Order
**Description:** Verify all 8 phases execute in the correct sequence.

**Acceptance Criteria:**
- [ ] Using `--dry-run` with verbose output, phase messages appear in order:
  1. Phase 1: Local Validation
  2. Phase 2: Software Installation
  3. Phase 3: Firewall (UFW)
  4. Phase 4: Registry Update
  5. Phase 5: Directory Setup
  6. Phase 6: Caddy Configuration
  7. Phase 7: PM2 Setup
  8. Phase 8: Summary
- [ ] Each phase completes before next begins (sequential execution)

**Dependencies:** Stories 1.7, 1.8
**Priority:** Should-have

---

### Story 1.10: Registry Creation - First Domain
**Description:** Verify that running on a fresh VPS creates the initial domains.json registry correctly.

**Acceptance Criteria:**
- [ ] Registry file is created at `/etc/caddy/domains.json` with version 1
- [ ] Registry contains `updated_at` timestamp in ISO 8601 format
- [ ] Registry contains `domains` object with the new domain entry
- [ ] Domain entry includes: `type` (static/dynamic), `added_at`, `updated_at`
- [ ] For dynamic domains, entry includes `port` and `app_dir`
- [ ] File permissions are 644 (root:root)

**Dependencies:** Stories 1.7, 1.8 (actual execution, not dry-run)
**Priority:** Must-have

---

### Story 1.11: Registry Merge - Adding Second Domain
**Description:** Verify that adding a domain from a different repo merges correctly into existing registry.

**Acceptance Criteria:**
- [ ] First domain exists in registry
- [ ] Running `setup-vps.sh` with different `DOMAIN` adds new entry
- [ ] Original domain remains unchanged in registry
- [ ] Both domains present after merge
- [ ] `added_at` of first domain preserved, only `updated_at` changed

**Dependencies:** Story 1.10
**Priority:** Must-have

---

### Story 1.12: Registry Update - Existing Domain
**Description:** Verify that re-running with same domain updates its configuration.

**Acceptance Criteria:**
- [ ] Domain exists in registry
- [ ] Change `DOMAIN_TYPE` or `DOMAIN_PORT` in `.env.deploy`
- [ ] Run `setup-vps.sh` again
- [ ] Domain entry is updated with new values
- [ ] `added_at` remains unchanged
- [ ] `updated_at` is refreshed
- [ ] Other domains in registry unaffected

**Dependencies:** Story 1.10
**Priority:** Must-have

---

### Story 1.13: Port Conflict Detection
**Description:** Verify that attempting to assign a port already in use by another dynamic domain fails with clear error.

**Acceptance Criteria:**
- [ ] Registry contains dynamic domain A with port 3000
- [ ] Attempt to add/update dynamic domain B with port 3000
- [ ] Script exits with code 1 BEFORE making any changes
- [ ] Error message lists the conflicting domain name and port
- [ ] Registry remains unchanged (no partial merge)

**Dependencies:** Story 1.11
**Priority:** Must-have

---

### Story 1.14: Caddyfile Generation - Static Domain
**Description:** Verify Caddyfile is generated correctly for static domains.

**Acceptance Criteria:**
- [ ] Generated Caddyfile includes `www` redirect block for domain
- [ ] Main block uses `root * /var/www/${DOMAIN}`
- [ ] Main block includes `file_server` and `try_files` directives
- [ ] Per-domain log file at `/var/log/caddy/${DOMAIN}.log`
- [ ] Security headers present: X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- [ ] Gzip encoding enabled
- [ ] Static asset caching headers for CSS/JS/images/fonts

**Dependencies:** Story 1.10
**Priority:** Must-have

---

### Story 1.15: Caddyfile Generation - Dynamic Domain
**Description:** Verify Caddyfile is generated correctly for dynamic domains.

**Acceptance Criteria:**
- [ ] Generated Caddyfile includes `www` redirect block
- [ ] Main block uses `reverse_proxy localhost:${DOMAIN_PORT}`
- [ ] Per-domain log file configured
- [ ] Security headers present
- [ ] Gzip encoding enabled
- [ ] No `root` or `file_server` directives

**Dependencies:** Story 1.13
**Priority:** Must-have

---

### Story 1.16: Caddyfile Generation - Multiple Domains Sorted
**Description:** Verify domains appear in alphabetical order in generated Caddyfile.

**Acceptance Criteria:**
- [ ] Registry contains domains: "zebra.com", "alpha.com", "beta.com"
- [ ] Generated Caddyfile lists them in order: alpha.com, beta.com, zebra.com
- [ ] Order is deterministic (same on repeated runs)

**Dependencies:** Story 1.11
**Priority:** Should-have

---

### Story 1.17: Caddyfile Backup and Validation
**Description:** Verify that existing Caddyfile is backed up before regeneration and validated after.

**Acceptance Criteria:**
- [ ] If Caddyfile exists, it is backed up to `/etc/caddy/backups/Caddyfile.YYYYMMDD_HHMMSS`
- [ ] Backup directory is created if missing
- [ ] New Caddyfile is validated with `caddy validate` before reload
- [ ] If validation fails, backup is restored and old config remains active
- [ ] Script exits with error if validation fails after backup restoration

**Dependencies:** Stories 1.14, 1.15 (actual execution)
**Priority:** Must-have

---

### Story 1.18: Caddy Reload on Config Changes
**Description:** Verify Caddy is reloaded only when configuration actually changes.

**Acceptance Criteria:**
- [ ] First run generates Caddyfile and reloads Caddy
- [ ] Second run with identical configuration detects no diff
- [ ] Second run logs "No Caddy config changes" and skips reload
- [ ] Third run with change (e.g., new domain) regenerates and reloads

**Dependencies:** Story 1.17
**Priority:** Should-have

---

### Story 1.19: Directory Setup - Static Domain
**Description:** Verify correct directory structure is created for static domains.

**Acceptance Criteria:**
- [ ] Directory `${VPS_BASE_PATH}/${DOMAIN}` is created (default: `/var/www/example.com`)
- [ ] Directory is owned by `VPS_USER` (default: deploy)
- [ ] Parent directories created if missing
- [ ] Directory permissions allow read/write for owner

**Dependencies:** Story 1.10 (actual execution)
**Priority:** Must-have

---

### Story 1.20: Directory Setup - Dynamic Domain
**Description:** Verify correct directory structure is created for dynamic domains.

**Acceptance Criteria:**
- [ ] Directory `${VPS_APPS_PATH}/${DOMAIN}` is created (default: `/home/deploy/apps/example.com`)
- [ ] Directory is owned by `VPS_USER`
- [ ] Caddy log directory `/var/log/caddy/` exists
- [ ] Caddy user (`www-data`) can write to log directory

**Dependencies:** Story 1.10 (actual execution)
**Priority:** Must-have

---

### Story 1.21: PM2 Setup - Dynamic Domain with App Code
**Description:** Verify PM2 process management when app code is already deployed.

**Acceptance Criteria:**
- [ ] `package.json` exists in app directory
- [ ] If PM2 process with name `${PM2_APP_NAME}` (or `${DOMAIN}`) exists, it is restarted
- [ ] If process doesn't exist, it is started with `pm2 start npm --name '${DOMAIN}' -- start`
- [ ] `pm2 save` is executed
- [ ] `pm2 startup` is configured if not already enabled (detected via `systemctl is-enabled pm2-${VPS_USER}`)
- [ ] PM2 process status is "online" after setup

**Dependencies:** Stories 1.19, 1.20 (directories created), deploy.sh must have run first
**Priority:** Must-have

---

### Story 1.22: PM2 Setup - Dynamic Domain without App Code
**Description:** Verify behavior when app code has not been deployed yet.

**Acceptance Criteria:**
- [ ] If `${VPS_APPS_PATH}/${DOMAIN}/package.json` does NOT exist
- [ ] PM2 start is skipped
- [ ] Reminder message is printed: "Deploy your app code to ${VPS_APPS_PATH}/${DOMAIN} then run: pm2 start npm --name '${DOMAIN}' -- start"
- [ ] `pm2 save` still executed
- [ ] `pm2 startup` configured if needed

**Dependencies:** Story 1.20 (directory created, but no code)
**Priority:** Should-have

---

### Story 1.23: Summary Status Table - All Domains
**Description:** Verify the summary table displays correct status for all domains in registry.

**Acceptance Criteria:**
- [ ] Table shows all domains from registry
- [ ] Columns: Domain, Type, Port, Status
- [ ] Static domain status: ✅ if `index.html` exists in web root, ⚠️ if missing
- [ ] Dynamic domain status: ✅ if PM2 process running and "online", ❌ if stopped/errored, ⚠️ if no process
- [ ] Table is formatted with borders and clear visual separation
- [ ] VPS IP is displayed in header

**Dependencies:** Stories 1.10-1.12 (registry populated)
**Priority:** Must-have

---

### Story 1.24: Status Subcommand
**Description:** Verify `setup-vps.sh status` displays registry information without making changes.

**Acceptance Criteria:**
- [ ] `./setup-vps.sh status` connects to VPS and reads `/etc/caddy/domains.json`
- [ ] Displays status table (same format as summary)
- [ ] Checks Caddy: domain present in active Caddyfile
- [ ] Checks Static: web root contains files
- [ ] Checks Dynamic: PM2 process running
- [ ] Checks SSL: `curl -sI https://${domain}` returns 200
- [ ] Displays Caddy service status (`systemctl is-active caddy`)
- [ ] Displays disk usage and memory summary
- [ ] No changes are made to VPS (read-only operation)
- [ ] Exit code 0

**Dependencies:** Stories 1.10-1.12 (registry must exist)
**Priority:** Must-have

---

### Story 1.25: Remove Subcommand - Confirmation
**Description:** Verify `setup-vps.sh remove` prompts for confirmation before making changes.

**Acceptance Criteria:**
- [ ] `./setup-vps.sh remove` reads `.env.deploy` to get `DOMAIN`
- [ ] If domain not in registry, logs "Domain 'X' not found in registry" and exits with code 0
- [ ] If domain exists, prints what will be removed:
  - Domain entry from registry
  - PM2 process stop/delete (if dynamic)
  - Caddyfile regeneration
- [ ] Prompts: "Are you sure? (y/N)"
- [ ] Any input other than 'y' or 'Y' aborts operation
- [ ] Confirmed ('y') proceeds with removal

**Dependencies:** Stories 1.10-1.12
**Priority:** Must-have

---

### Story 1.26: Remove Subcommand - Execution
**Description:** Verify removal actually removes domain and cleans up.

**Acceptance Criteria:**
- [ ] Domain is removed from `/etc/caddy/domains.json`
- [ ] If dynamic: PM2 process is stopped and deleted (`pm2 delete ${DOMAIN}`)
- [ ] Caddyfile is regenerated from remaining registry entries
- [ ] Caddy is reloaded with new config
- [ ] `pm2 save` is executed
- [ ] Reminder printed: "Files at /var/www/${DOMAIN} (or /home/deploy/apps/${DOMAIN}) were NOT deleted. Remove manually if desired."
- [ ] Domain no longer accessible via HTTPS

**Dependencies:** Story 1.25 (confirmed removal)
**Priority:** Must-have

---

### Story 1.27: Idempotency - Repeated Runs
**Description:** Verify script can be safely run multiple times with same configuration.

**Acceptance Criteria:**
- [ ] First run completes successfully, creates/updates registry, generates Caddyfile, reloads Caddy
- [ ] Second run with identical `.env.deploy`:
  - No errors
  - Registry unchanged (timestamps may update but structure same)
  - Caddyfile identical (diff shows no changes)
  - Caddy not reloaded (or logs "No Caddy config changes")
  - Summary table shows same status
- [ ] Third run identical to second

**Dependencies:** Stories 1.10-1.18
**Priority:** Must-have

---

### Story 1.28: SSH Connection Failure
**Description:** Verify clear error when VPS is unreachable.

**Acceptance Criteria:**
- [ ] With invalid `VPS_IP` or SSH service down
- [ ] Script attempts SSH connection with timeout (10s) and batch mode
- [ ] On failure, exits with code 1
- [ ] Error message: "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
- [ ] Suggests checking: SSH key, VPS_USER, VPS_IP, SSH_PORT
- [ ] No partial changes made (registry not updated, directories not created)

**Dependencies:** Story 1.1
**Priority:** Must-have

---

### Story 1.29: Registry Corruption Recovery
**Description:** Verify behavior when `/etc/caddy/domains.json` is missing or contains invalid JSON.

**Acceptance Criteria:**
- [ ] If registry file missing: creates fresh empty registry with version 1 and empty domains object
- [ ] If registry contains invalid JSON:
  - Backs up corrupted file to `/etc/caddy/domains.json.corrupt.TIMESTAMP`
  - Creates fresh empty registry
  - Logs warning about corruption and backup location
  - Continues with fresh registry
- [ ] Current domain is then added to fresh registry

**Dependencies:** Story 1.10 (actual execution)
**Priority:** Should-have

---

### Story 1.30: Caddy Validation Failure Recovery
**Description:** Verify rollback when generated Caddyfile fails validation.

**Acceptance Criteria:**
- [ ] Simulate invalid Caddyfile (e.g., corrupt registry with invalid port type)
- [ ] Script attempts `caddy validate` after generation
- [ ] On validation failure:
  - Backup of new invalid Caddyfile is saved
  - Previous Caddyfile is restored from backup
  - Caddy is NOT reloaded (old config stays active)
  - Error message logged explaining the failure
  - Exit code 1
- [ ] VPS remains functional with previous configuration

**Dependencies:** Story 1.17
**Priority:** Must-have

---

### Story 1.31: Domain Type Change - Static to Dynamic
**Description:** Verify changing a domain from static to dynamic updates all components correctly.

**Acceptance Criteria:**
- [ ] Domain exists as static in registry
- [ ] Update `.env.deploy` to `DOMAIN_TYPE=dynamic` with valid `DOMAIN_PORT`
- [ ] Run `setup-vps.sh`
- [ ] Registry entry updated to dynamic with port
- [ ] Dynamic app directory created at `${VPS_APPS_PATH}/${DOMAIN}`
- [ ] Caddyfile regenerated with `reverse_proxy` instead of `root/file_server`
- [ ] Caddy reloaded
- [ ] Logs message about type change
- [ ] Static directory at `/var/www/${DOMAIN}` is NOT automatically deleted (documented behavior)

**Dependencies:** Stories 1.12, 1.20
**Priority:** Should-have

---

### Story 1.32: Domain Type Change - Dynamic to Static
**Description:** Verify changing a domain from dynamic to static updates components and stops PM2.

**Acceptance Criteria:**
- [ ] Domain exists as dynamic in registry
- [ ] Update `.env.deploy` to `DOMAIN_TYPE=static` (remove `DOMAIN_PORT`)
- [ ] Run `setup-vps.sh`
- [ ] Registry updated to static (port removed)
- [ ] Static web root created at `${VPS_BASE_PATH}/${DOMAIN}`
- [ ] Caddyfile regenerated with `file_server` instead of `reverse_proxy`
- [ ] Caddy reloaded
- [ ] PM2 process for domain is stopped and deleted
- [ ] `pm2 save` executed
- [ ] Logs message about type change and PM2 removal
- [ ] Dynamic app directory at `/home/deploy/apps/${DOMAIN}` is NOT automatically deleted

**Dependencies:** Stories 1.12, 1.21, 1.26
**Priority:** Should-have

---

### Story 1.33: Software Installation - Caddy
**Description:** Verify Caddy installation from official repository on fresh VPS.

**Acceptance Criteria:**
- [ ] On fresh VPS with no Caddy: script installs via official apt repository
- [ ] Commands executed:
  - Add Cloudflare GPG key
  - Add Caddy apt repository
  - `apt update`
  - `apt install caddy -y`
- [ ] After install, `caddy version` succeeds
- [ ] Caddy service is enabled and running
- [ ] On subsequent runs, installation is skipped and version is logged

**Dependencies:** Story 1.10 (actual execution on fresh VPS)
**Priority:** Must-have

---

### Story 1.34: Software Installation - jq
**Description:** Verify jq installation for JSON processing.

**Acceptance Criteria:**
- [ ] If `jq --version` fails, script installs via `sudo apt install -y jq`
- [ ] After install, `jq --version` succeeds
- [ ] jq is available for registry manipulation

**Dependencies:** Story 1.10 (actual execution)
**Priority:** Must-have

---

### Story 1.35: Software Installation - Node.js and PM2 (Conditional)
**Description:** Verify Node.js and PM2 are only installed if any domain in registry is dynamic.

**Acceptance Criteria:**
- [ ] Fresh VPS, first domain is static: Node.js and PM2 are NOT installed
- [ ] Second domain is dynamic: script detects existing dynamic domain in registry
- [ ] Node.js installed via nvm (latest LTS) for deploy user
- [ ] PM2 installed globally via npm
- [ ] `pm2 startup` configured for deploy user
- [ ] If registry already has dynamic domains, new static domain run does NOT uninstall Node.js/PM2 (they remain)

**Dependencies:** Stories 1.11, 1.10
**Priority:** Must-have

---

### Story 1.36: Firewall Configuration - UFW
**Description:** Verify UFW firewall is configured with correct rules.

**Acceptance Criteria:**
- [ ] Script checks if UFW is active (`sudo ufw status`)
- [ ] Ensures rules exist for ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- [ ] If rules missing, adds them with `sudo ufw allow <port>/tcp`
- [ ] If UFW is inactive, enables it with `sudo ufw --force enable` (after ensuring SSH rule exists to avoid lockout)
- [ ] Final status shows rules in order: 22, 80, 443
- [ ] Default deny policy is in place (if UFW was fresh)

**Dependencies:** Story 1.10 (actual execution)
**Priority:** Must-have

---

### Story 1.37: Verbose Mode
**Description:** Verify `--verbose` flag shows detailed SSH command output.

**Acceptance Criteria:**
- [ ] With `--verbose`, script shows stdout/stderr from remote commands
- [ ] Without `--verbose`, remote command output is suppressed (only local logs)
- [ ] Verbose mode works with all subcommands (setup, status, remove)
- [ ] Can be combined with `--dry-run`

**Dependencies:** Story 1.10 (actual execution)
**Priority:** Should-have

---

## Epic 2: deploy.sh Core Functionality Testing

### Story 2.1: Script Syntax and Static Analysis
**Description:** Verify `deploy.sh` passes basic syntax and quality checks.

**Acceptance Criteria:**
- [ ] `bash -n deploy.sh` exits with code 0
- [ ] `shellcheck deploy.sh` produces no warnings or errors
- [ ] Script has proper shebang and executable permissions

**Dependencies:** None
**Priority:** Must-have

---

### Story 2.2: Configuration Loading and Validation
**Description:** Verify `.env.deploy` is loaded correctly and required variables are validated.

**Acceptance Criteria:**
- [ ] Script loads `.env.deploy` from same directory
- [ ] Required variables: `VPS_USER`, `VPS_IP`, `DOMAIN`, `DOMAIN_TYPE`
- [ ] If missing, error message shows which variable and exits with code 1
- [ ] Optional variables use defaults: `VPS_BASE_PATH=/var/www`, `VPS_APPS_PATH=/home/deploy/apps`, `SSH_PORT=22`, `BUILD_CMD="npm run build"`, `BUILD_OUTPUT="out"`
- [ ] `DOMAIN_PORT` validated if `DOMAIN_TYPE=dynamic` (same rules as setup-vps.sh)

**Dependencies:** Story 2.1
**Priority:** Must-have

---

### Story 2.3: Build Phase - Static Site
**Description:** Verify build process for static Next.js export.

**Acceptance Criteria:**
- [ ] `package.json` exists in project root
- [ ] `BUILD_CMD` is executed (default: `npm run build`)
- [ ] After build, `BUILD_OUTPUT` directory exists (default: `out/`)
- [ ] Script counts files in output directory and logs count
- [ ] If `BUILD_OUTPUT` missing after build, error and exit code 1
- [ ] If `--skip-build` used, build is skipped and `BUILD_OUTPUT` must already exist

**Dependencies:** Story 2.2
**Priority:** Must-have

---

### Story 2.4: Deploy Phase - Static Site Rsync
**Description:** Verify static site files are rsynced to correct VPS location.

**Acceptance Criteria:**
- [ ] Target path: `${VPS_BASE_PATH}/${DOMAIN}/` (default: `/var/www/example.com/`)
- [ ] Rsync command: `rsync -az --delete ${BUILD_OUTPUT}/ ${VPS_USER}@${VPS_IP}:${VPS_BASE_PATH}/${DOMAIN}/`
- [ ] SSH connection tested before rsync (timeout 10s, batch mode)
- [ ] Remote directory created if missing (`mkdir -p`)
- [ ] With `--dry-run`, rsync uses `--dry-run` flag and no files transferred
- [ ] With `--verbose`, rsync shows detailed transfer progress
- [ ] After successful rsync, prints verification URL: `https://${DOMAIN}`

**Dependencies:** Stories 2.2, 2.3
**Priority:** Must-have

---

### Story 2.5: Deploy Phase - Dynamic Site Rsync
**Description:** Verify dynamic site code is rsynced with proper exclusions.

**Acceptance Criteria:**
- [ ] Target path: `${VPS_APPS_PATH}/${DOMAIN}/` (default: `/home/deploy/apps/example.com/`)
- [ ] Rsync command: `rsync -az --delete --exclude='node_modules' --exclude='.next/cache' ./ ${VPS_USER}@${VPS_IP}:${VPS_APPS_PATH}/${DOMAIN}/`
- [ ] Entire project directory (excluding specified patterns) is transferred
- [ ] Exclusions prevent unnecessary files from being copied
- [ ] SSH connection tested, remote directory created

**Dependencies:** Stories 2.2, 2.3
**Priority:** Must-have

---

### Story 2.6: Post-Deploy - Dynamic Site NPM Install and PM2 Restart
**Description:** Verify post-deploy steps for dynamic sites.

**Acceptance Criteria:**
- [ ] After rsync completes, SSH into VPS
- [ ] Run: `cd ${VPS_APPS_PATH}/${DOMAIN} && npm install --production`
- [ ] Run: `npm run build` (if build step needed on server)
- [ ] Run: `pm2 restart ${DOMAIN}` (or `${PM2_APP_NAME}` if set)
- [ ] If PM2 process doesn't exist, start it: `pm2 start npm --name '${DOMAIN}' -- start`
- [ ] Logs success message with verification URL

**Dependencies:** Stories 2.5 (dynamic only)
**Priority:** Must-have

---

### Story 2.7: Multi-Domain Deployment (Legacy Behavior)
**Description:** Verify that the refactored script still supports single-domain mode as per PRD.

**Acceptance Criteria:**
- [ ] Script reads single `DOMAIN` from `.env.deploy`
- [ ] No interactive domain selection (that was legacy multi-domain behavior)
- [ ] Deploys only to the configured domain
- [ ] If user tries to pass domain as argument, script ignores it or shows error (PRD says single-domain pattern)

**Dependencies:** Story 2.2
**Priority:** Must-have

---

### Story 2.8: Dry-Run Mode
**Description:** Verify `--dry-run` shows what would be transferred without making changes.

**Acceptance Criteria:**
- [ ] With `--dry-run`, build still runs (unless `--skip-build`)
- [ ] Rsync uses `--dry-run` flag
- [ ] Post-deploy SSH commands are NOT executed
- [ ] No files transferred to VPS
- [ ] Summary shows "Dry run complete" instead of "All done!"

**Dependencies:** Stories 2.3-2.6
**Priority:** Must-have

---

### Story 2.9: Skip-Build Mode
**Description:** Verify `--skip-build` uses existing build output without rebuilding.

**Acceptance Criteria:**
- [ ] With `--skip-build`, build phase is skipped
- [ ] Script verifies `BUILD_OUTPUT` directory exists locally
- [ ] If missing, error: "Build output directory '${BUILD_OUTPUT}/' not found. Run without --skip-build first."
- [ ] Deploy phase proceeds with existing output

**Dependencies:** Story 2.3
**Priority:** Should-have

---

### Story 2.10: SSH Connection Failure
**Description:** Verify clear error when VPS is unreachable during deploy.

**Acceptance Criteria:**
- [ ] Before rsync, SSH connection test performed
- [ ] On failure: error "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
- [ ] Suggests checking SSH key, user, IP, port
- [ ] Exit code 1, no deploy attempted

**Dependencies:** Story 2.4, 2.5
**Priority:** Must-have

---

### Story 2.11: Build Failure
**Description:** Verify script handles build command failure gracefully.

**Acceptance Criteria:**
- [ ] If `BUILD_CMD` exits with non-zero status, script exits immediately
- [ ] Error message: "Build failed" (or actual build error output)
- [ ] No deploy attempted
- [ ] Exit code reflects build failure

**Dependencies:** Story 2.3
**Priority:** Must-have

---

### Story 2.12: Rsync Failure
**Description:** Verify script handles rsync failures (network, permissions, disk space).

**Acceptance Criteria:**
- [ ] If rsync exits with non-zero, script exits with error
- [ ] Error message includes rsync output
- [ ] Common causes suggested: network issue, disk full, permission denied
- [ ] Exit code reflects rsync failure

**Dependencies:** Stories 2.4, 2.5
**Priority:** Must-have

---

### Story 2.13: Post-Deploy Failure - Dynamic
**Description:** Verify script handles npm install or PM2 restart failures.

**Acceptance Criteria:**
- [ ] If `npm install --production` fails, script exits with error
- [ ] If `npm run build` fails, script exits with error
- [ ] If `pm2 restart` fails, script exits with error
- [ ] Error messages include command output for debugging
- [ ] Script does NOT continue after post-deploy failure

**Dependencies:** Story 2.6
**Priority:** Must-have

---

### Story 2.14: Summary and Timing
**Description:** Verify deploy summary includes timing and verification URL.

**Acceptance Criteria:**
- [ ] Start time recorded before deploy operations
- [ ] End time recorded after all operations complete
- [ ] Elapsed time calculated and displayed
- [ ] Success message: "All done! (Xs)" or "Dry run complete (Xs)"
- [ ] Verification URL printed: `https://${DOMAIN}`
- [ ] If dry-run, appropriate message shown

**Dependencies:** Stories 2.4-2.6
**Priority:** Should-have

---

## Epic 3: Integration and End-to-End Testing

### Story 3.1: Full Workflow - Static Domain
**Description:** Complete end-to-end test: setup VPS then deploy static site.

**Acceptance Criteria:**
- [ ] Fresh VPS (Ubuntu 22.04/24.04, deploy user with sudo, no Caddy/Node/PM2)
- [ ] Run `./setup-vps.sh` with static domain config
- [ ] VPS has Caddy installed and running
- [ ] `/etc/caddy/domains.json` created with domain entry
- [ ] `/var/www/example.com/` exists and owned by deploy
- [ ] Caddyfile generated and Caddy reloaded
- [ ] Run `./deploy.sh` (or `./deploy.sh --skip-build` if build already done)
- [ ] Static files transferred to `/var/www/example.com/`
- [ ] `https://example.com` returns 200 and serves site
- [ ] SSL certificate obtained automatically by Caddy

**Dependencies:** Stories 1.1-1.39, 2.1-2.14
**Priority:** Must-have

---

### Story 3.2: Full Workflow - Dynamic Domain
**Description:** Complete end-to-end test: setup VPS then deploy dynamic Next.js app.

**Acceptance Criteria:**
- [ ] Fresh VPS
- [ ] Run `./setup-vps.sh` with dynamic domain config (port 3000)
- [ ] VPS has Caddy, Node.js (nvm LTS), PM2 installed
- [ ] `/home/deploy/apps/example.com/` exists
- [ ] Caddyfile generated with reverse_proxy to localhost:3000
- [ ] Caddy reloaded
- [ ] Run `./deploy.sh`
- [ ] Project code transferred to `/home/deploy/apps/example.com/`
- [ ] Post-deploy: `npm install --production` executed
- [ ] Post-deploy: `npm run build` executed (if needed)
- [ ] PM2 process started and running
- [ ] `https://example.com` returns 200 and serves Next.js app
- [ ] SSL certificate obtained

**Dependencies:** Stories 1.1-1.39, 2.1-2.14
**Priority:** Must-have

---

### Story 3.3: Multiple Domains on Same VPS
**Description:** Verify adding multiple domains from different repos works correctly.

**Acceptance Criteria:**
- [ ] Repo A (static domain A): run `setup-vps.sh` → domain A configured
- [ ] Repo B (static domain B): run `setup-vps.sh` → both domains A and B in registry
- [ ] Repo C (dynamic domain C): run `setup-vps.sh` → all three domains in registry
- [ ] Caddyfile contains all three domains in alphabetical order
- [ ] Caddy reloaded successfully
- [ ] All three domains accessible via HTTPS with valid SSL
- [ ] Each domain serves correct content (static A, static B, dynamic C)
- [ ] `setup-vps.sh status` shows all three with correct status

**Dependencies:** Stories 3.1, 3.2
**Priority:** Must-have

---

### Story 3.4: Domain Type Change - Static to Dynamic
**Description:** Verify full workflow of changing a domain from static to dynamic.

**Acceptance Criteria:**
- [ ] Domain initially set up as static, site deployed and working
- [ ] Update `.env.deploy` to `DOMAIN_TYPE=dynamic` with port
- [ ] Run `setup-vps.sh`
- [ ] Registry updated, Node.js/PM2 installed (if not already)
- [ ] Dynamic app directory created
- [ ] Caddyfile updated with reverse_proxy
- [ ] Caddy reloaded
- [ ] Deploy dynamic app code with `deploy.sh`
- [ ] Post-deploy: npm install, build, PM2 start
- [ ] Domain now serves dynamic app
- [ ] Old static files remain in `/var/www/` (not deleted automatically)

**Dependencies:** Stories 3.1, 3.2, 1.31
**Priority:** Should-have

---

### Story 3.5: Domain Type Change - Dynamic to Static
**Description:** Verify full workflow of changing a domain from dynamic to static.

**Acceptance Criteria:**
- [ ] Domain initially set up as dynamic, app running via PM2
- [ ] Update `.env.deploy` to `DOMAIN_TYPE=static` (remove port)
- [ ] Run `setup-vps.sh`
- [ ] Registry updated, PM2 process stopped and deleted
- [ ] Static web root created
- [ ] Caddyfile updated with file_server
- [ ] Caddy reloaded
- [ ] Deploy static build with `deploy.sh`
- [ ] Domain now serves static site
- [ ] Old app code remains in `/home/deploy/apps/` (not deleted automatically)

**Dependencies:** Stories 3.1, 3.2, 1.32
**Priority:** Should-have

---

### Story 3.6: Remove Domain - Static
**Description:** Verify complete removal of static domain.

**Acceptance Criteria:**
- [ ] Static domain exists and working
- [ ] Run `./setup-vps.sh remove` and confirm
- [ ] Domain removed from registry
- [ ] Caddyfile regenerated without domain
- [ ] Caddy reloaded
- [ ] `https://example.com` no longer resolves (connection refused or 404 from default Caddy)
- [ ] Files remain in `/var/www/example.com/` (as documented)
- [ ] `setup-vps.sh status` no longer shows domain

**Dependencies:** Stories 3.1, 1.26
**Priority:** Must-have

---

### Story 3.7: Remove Domain - Dynamic
**Description:** Verify complete removal of dynamic domain.

**Acceptance Criteria:**
- [ ] Dynamic domain exists and PM2 process running
- [ ] Run `./setup-vps.sh remove` and confirm
- [ ] Domain removed from registry
- [ ] PM2 process stopped and deleted
- [ ] `pm2 save` executed
- [ ] Caddyfile regenerated and reloaded
- [ ] Domain no longer accessible via HTTPS
- [ ] App code remains in `/home/deploy/apps/example.com/`
- [ ] `setup-vps.sh status` no longer shows domain

**Dependencies:** Stories 3.2, 1.26
**Priority:** Must-have

---

### Story 3.8: Status Command - Comprehensive View
**Description:** Verify `setup-vps.sh status` provides accurate information for all domains.

**Acceptance Criteria:**
- [ ] Mixed static and dynamic domains configured
- [ ] Run `./setup-vps.sh status`
- [ ] Table shows all domains with correct type and port
- [ ] Static domain with files: ✅
- [ ] Static domain without files: ⚠️
- [ ] Dynamic domain with PM2 online: ✅
- [ ] Dynamic domain with PM2 stopped: ❌
- [ ] Dynamic domain with no PM2 process: ⚠️
- [ ] SSL check: domains returning 200 show valid cert
- [ ] Caddy service status shown
- [ ] Disk usage and memory summary displayed
- [ ] Exit code 0

**Dependencies:** Stories 3.1, 3.2, 1.24
**Priority:** Must-have

---

## Epic 4: Error Handling and Edge Cases

### Story 4.1: Invalid SSH Key
**Description:** Verify script handles non-existent or invalid SSH key.

**Acceptance Criteria:**
- [ ] `SSH_KEY` points to non-existent file in `.env.deploy`
- [ ] SSH connection attempt fails with "Permission denied" or "Invalid key"
- [ ] Script exits with clear error: "Cannot connect... Check your SSH key"
- [ ] No changes made to VPS

**Dependencies:** None (can test with dry-run or real VPS)
**Priority:** Should-have

---

### Story 4.2: Non-Root Deploy User Without Sudo
**Description:** Verify behavior when deploy user lacks sudo privileges.

**Acceptance Criteria:**
- [ ] Deploy user exists but not in sudo group
- [ ] Script attempts sudo command (e.g., Caddy install)
- [ ] sudo fails with permission error
- [ ] Script catches error and logs: "User does not have sudo privileges"
- [ ] Suggests adding user to sudo group: `sudo usermod -aG sudo deploy`
- [ ] Exit code 1

**Dependencies:** Actual execution on VPS with misconfigured user
**Priority:** Should-have

---

### Story 4.3: Disk Full Scenario
**Description:** Verify script handles out-of-disk-space condition gracefully.

**Acceptance Criteria:**
- [ ] Simulate full disk (or nearly full) on VPS
- [ ] Rsync attempt fails with "No space left on device"
- [ ] Script exits with error showing rsync output
- [ ] No partial deployment overwrites existing files (rsync is atomic per file)
- [ ] Error message suggests checking disk usage

**Dependencies:** Actual execution with controlled disk quota
**Priority:** Should-have

---

### Story 4.4: Network Interruption During Rsync
**Description:** Verify rsync handles network drop gracefully.

**Acceptance Criteria:**
- [ ] Simulate network interruption during large file transfer
- [ ] Rsync exits with non-zero status
- [ ] Script catches error and exits
- [ ] Partial files on VPS are in consistent state (rsync atomicity)
- [ ] User can retry deploy (rsync will resume/skip as appropriate)

**Dependencies:** Actual execution with network control
**Priority:** Could-have

---

### Story 4.5: Domain with Subdomains
**Description:** Verify handling of subdomain configurations (e.g., `app.example.com`).

**Acceptance Criteria:**
- [ ] `.env.deploy` with `DOMAIN=app.example.com`
- [ ] `setup-vps.sh` creates registry entry with full subdomain
- [ ] Caddyfile includes both `www.app.example.com` redirect and `app.example.com` block
- [ ] Directory paths use full domain: `/var/www/app.example.com/`
- [ ] Log file: `/var/log/caddy/app.example.com.log`
- [ ] Deploy and access works via `https://app.example.com`

**Dependencies:** Stories 3.1, 3.2
**Priority:** Should-have

---

### Story 4.6: Very Long Domain Name
**Description:** Verify handling of unusually long domain names (63 character limit per label).

**Acceptance Criteria:**
- [ ] Domain with 63-character subdomain label
- [ ] Registry stores full domain correctly
- [ ] Caddyfile generated without line wrapping issues
- [ ] Directory paths created with long name
- [ ] No truncation in logs or status displays

**Dependencies:** Story 1.10
**Priority:** Could-have

---

### Story 4.7: Port Already in Use by Non-PM2 Service
**Description:** Verify detection when a port is occupied by a non-PM2 process.

**Acceptance Criteria:**
- [ ] Some other service (e.g., another web server) listening on port 3000
- [ ] Dynamic domain configured with `DOMAIN_PORT=3000`
- [ ] `setup-vps.sh` checks port conflict ONLY against other domains in registry
- [ ] Does NOT check against system-wide port usage (by design)
- [ ] PM2 start may fail if port is taken, but that's separate
- [ ] Document this limitation: port conflict check is only within registry

**Dependencies:** Story 1.13
**Priority:** Could-have

---

### Story 4.8: Concurrent Execution Safety
**Description:** Document and test potential race conditions.

**Acceptance Criteria:**
- [ ] Document that script is NOT designed for concurrent execution
- [ ] If two instances run simultaneously, registry may corrupt
- [ ] No locking mechanism implemented (by design for simplicity)
- [ ] Recommendation: serialize runs (e.g., via CI/CD pipeline)
- [ ] Test: running two instances in parallel shows unpredictable results (document observed behavior)

**Dependencies:** Story 1.10 (registry write)
**Priority:** Could-have

---

### Story 4.9: Caddy Already Running on Different Port
**Description:** Verify behavior when Caddy is already installed but configured differently.

**Acceptance Criteria:**
- [ ] Caddy installed but Caddyfile exists from manual setup
- [ ] `setup-vps.sh` backs up existing Caddyfile before overwriting
- [ ] Backup saved with timestamp
- [ ] New Caddyfile generated from registry
- [ ] Caddy reloaded with new config
- [ ] Old config available in backups/

**Dependencies:** Story 1.17
**Priority:** Should-have

---

### Story 4.10: VPS with Pre-Existing Node.js (Non-nvm)
**Description:** Verify behavior when Node.js is already installed system-wide (not via nvm).

**Acceptance Criteria:**
- [ ] VPS has Node.js from nodesource or other method
- [ ] `node --version` succeeds
- [ ] Script detects Node.js is installed and skips nvm installation
- [ ] PM2 check/install proceeds normally
- [ ] No conflicts, script works correctly

**Dependencies:** Story 1.35
**Priority:** Should-have

---

## Epic 5: VPS Deployment Scenarios and Operations

### Story 5.1: Fresh VPS Setup - All Dependencies
**Description:** Complete provisioning of a brand-new VPS with no prior configuration.

**Acceptance Criteria:**
- [ ] Ubuntu 22.04 or 24.04 freshly created
- [ ] Non-root user `deploy` exists with sudo
- [ ] SSH key authentication set up
- [ ] No Caddy, Node.js, PM2, jq installed
- [ ] Run `./setup-vps.sh` with static domain
- [ ] All software installed: Caddy, jq
- [ ] UFW configured with 22, 80, 443
- [ ] Directory structure created
- [ ] Registry and Caddyfile generated
- [ ] Caddy running and serving domain (after DNS and deploy)
- [ ] Total time: < 10 minutes

**Dependencies:** All setup-vps.sh stories
**Priority:** Must-have

---

### Story 5.2: Incremental Domain Addition
**Description:** Adding domains to an already-configured VPS over time.

**Acceptance Criteria:**
- [ ] VPS already has domain A configured
- [ ] New project repo with domain B
- [ ] Copy `setup-vps.sh` and `.env.deploy` to new repo
- [ ] Configure `.env.deploy` for domain B
- [ ] Run `./setup-vps.sh` from new repo
- [ ] Domain B added to registry
- [ ] Caddyfile regenerated with both A and B
- [ ] Caddy reloaded
- [ ] No impact on domain A
- [ ] Can repeat for domains C, D, etc.

**Dependencies:** Story 5.1
**Priority:** Must-have

---

### Story 5.3: Registry Backup and Restore
**Description:** Manual backup and restore of the central registry.

**Acceptance Criteria:**
- [ ] Backup: `sudo cp /etc/caddy/domains.json /backup/domains.json.backup`
- [ ] Simulate corruption: edit registry to invalid JSON
- [ ] Run `./setup-vps.sh` (any domain)
- [ ] Script detects corruption, creates `.corrupt` backup, creates fresh registry
- [ ] Manual restore: replace `/etc/caddy/domains.json` with backup
- [ ] Run `./setup-vps.sh` to regenerate Caddyfile from restored registry
- [ ] All domains back online

**Dependencies:** Story 1.29
**Priority:** Should-have

---

### Story 5.4: Caddyfile Backup Rotation
**Description:** Verify backup strategy for Caddyfile.

**Acceptance Criteria:**
- [ ] Each regeneration creates timestamped backup in `/etc/caddy/backups/`
- [ ] Backup format: `Caddyfile.YYYYMMDD_HHMMSS`
- [ ] Old backups are NOT automatically pruned (manual cleanup)
- [ ] Can manually restore from any backup
- [ ] Disk space impact is minimal (text files)

**Dependencies:** Story 1.17
**Priority:** Should-have

---

### Story 5.5: PM2 Process Recovery
**Description:** Verify PM2 startup and recovery after VPS reboot.

**Acceptance Criteria:**
- [ ] Dynamic domain running with PM2
- [ ] `pm2 startup` has been configured
- [ ] Reboot VPS: `sudo reboot`
- [ ] After reboot, check `systemctl status pm2-deploy` (or similar)
- [ ] PM2 service starts automatically
- [ ] Check `pm2 list` shows app in "online" status
- [ ] If app not started, `pm2 resurrect` may be needed (document behavior)

**Dependencies:** Story 1.21
**Priority:** Must-have

---

### Story 5.6: SSL Certificate Renewal
**Description:** Verify Let's Encrypt certificates auto-renew via Caddy.

**Acceptance Criteria:**
- [ ] Domain configured and accessible via HTTPS
- [ ] Check certificate: `sudo caddy list-certificates`
- [ ] Certificate expiry is ~90 days
- [ ] Caddy auto-renews before expiry (document typical renewal window)
- [ ] Renewal is seamless (no downtime)
- [ ] Test renewal: manually trigger with `sudo caddy reload` (Caddy will renew if needed)

**Dependencies:** Story 3.1 or 3.2 (working HTTPS)
**Priority:** Must-have

---

### Story 5.7: DNS Propagation and Domain Addition
**Description:** Verify workflow when DNS is not yet propagated.

**Acceptance Criteria:**
- [ ] Domain's A record not yet pointing to VPS IP
- [ ] Run `setup-vps.sh` → Caddyfile generated, Caddy reloaded
- [ ] Run `deploy.sh` → files transferred
- [ ] `https://domain` may not work yet (DNS not propagated)
- [ ] Once DNS propagates, site works automatically
- [ ] Caddy will obtain SSL certificate on first successful HTTPS request
- [ ] Document that DNS must propagate before site is accessible

**Dependencies:** Stories 3.1, 3.2
**Priority:** Must-have

---

### Story 5.8: Rolling Back to Previous Configuration
**Description:** Verify manual rollback procedure using Caddyfile backups.

**Acceptance Criteria:**
- [ ] Current Caddyfile is `/etc/caddy/Caddyfile`
- [ ] List backups in `/etc/caddy/backups/`
- [ ] Choose backup: `sudo cp /etc/caddy/backups/Caddyfile.20250217_100000 /etc/caddy/Caddyfile`
- [ ] Validate: `sudo caddy validate`
- [ ] Reload: `sudo systemctl reload caddy`
- [ ] Previous domain configuration restored
- [ ] Document this as manual recovery procedure

**Dependencies:** Story 1.17
**Priority:** Should-have

---

## Epic 6: Documentation and Configuration Validation

### Story 6.1: .env.deploy.example Completeness
**Description:** Verify the example configuration file includes all required and optional variables.

**Acceptance Criteria:**
- [ ] File exists at `.env.deploy.example`
- [ ] Includes all required variables: `VPS_USER`, `VPS_IP`, `DOMAIN`, `DOMAIN_TYPE`
- [ ] Includes conditional required: `DOMAIN_PORT` (with comment: required if dynamic)
- [ ] Includes all optional with defaults: `SSH_KEY`, `SSH_PORT`, `VPS_BASE_PATH`, `VPS_APPS_PATH`, `BUILD_CMD`, `BUILD_OUTPUT`, `PM2_APP_NAME`
- [ ] Each variable has descriptive comment
- [ ] Template is copy-paste ready: `cp .env.deploy.example .env.deploy`

**Dependencies:** None
**Priority:** Must-have

---

### Story 6.2: README.md Accuracy
**Description:** Verify README matches actual script behavior.

**Acceptance Criteria:**
- [ ] Quick Start section: 5-step guide works on fresh VPS
- [ ] Prerequisites list matches actual requirements (Ubuntu 22.04/24.04, SSH, etc.)
- [ ] Configuration section documents all `.env.deploy` variables with validation rules
- [ ] Usage section documents:
  - `setup-vps.sh` (default, status, remove) with options
  - `deploy.sh` with options (--skip-build, --dry-run, --verbose)
- [ ] Architecture diagram (text-based) matches PRD §3
- [ ] "Adding a New Domain" step-by-step is accurate
- [ ] "Switching Static ↔ Dynamic" explains what changes in `.env.deploy` and what happens on VPS
- [ ] Troubleshooting covers common issues from test results
- [ ] Links to `docs/manual-setup-guide.md`

**Dependencies:** All functional stories
**Priority:** Must-have

---

### Story 6.3: Manual Setup Guide Consistency
**Description:** Verify `docs/manual-setup-guide.md` matches script automation.

**Acceptance Criteria:**
- [ ] Each section corresponds to a phase in `setup-vps.sh`
- [ ] Manual commands match what script executes
- [ ] Directory paths, file locations, and commands are identical
- [ ] Guide includes all steps: user setup, Caddy install, Node.js/PM2, jq, UFW, directories, registry, Caddyfile, verification
- [ ] Documented as reference for understanding automation
- [ ] Cross-referenced in README

**Dependencies:** Story 1.1-1.39 (script implementation)
**Priority:** Must-have

---

### Story 6.4: PRD Compliance Check
**Description:** Verify implementation matches PRD specifications.

**Acceptance Criteria:**
- [ ] All PRD §5 phases implemented in `setup-vps.sh` in correct order
- [ ] All PRD §6 phases implemented in `deploy.sh`
- [ ] Registry schema matches PRD §3.3 exactly
- [ ] Caddyfile templates match PRD §5.4 for static and dynamic
- [ ] All edge cases from PRD §9 are handled
- [ ] Security considerations from PRD §10 are implemented
- [ ] File inventory from PRD §7.2 matches actual VPS artifacts

**Dependencies:** Complete implementation
**Priority:** Must-have

---

### Story 6.5: Test Plan Execution Against Implementation
**Description:** Execute the test plan in `plans/test-setup-vps.sh.md` and verify all tests pass.

**Acceptance Criteria:**
- [ ] All syntax checks (Story 1.1) pass
- [ ] All help/usage tests (Story 1.2) pass
- [ ] All configuration validation tests (Stories 1.3-1.6) pass
- [ ] All dry-run tests (Stories 1.7, 1.8) pass
- [ ] Phase order test (Story 1.9) passes
- [ ] All registry management tests (Stories 1.10-1.13) pass
- [ ] All Caddyfile generation tests (Stories 1.14-1.16) pass
- [ ] All error handling tests (Stories 1.17, 1.28-1.30) pass
- [ ] Idempotency test (Story 1.27) passes
- [ ] All subcommand tests (Stories 1.24-1.26) pass
- [ ] All edge case tests (Stories 1.31-1.36) pass
- [ ] Document any failures and fix implementation

**Dependencies:** Complete implementation of setup-vps.sh
**Priority:** Must-have

---

### Story 6.6: Deploy.sh Test Plan Creation and Execution
**Description:** Create comprehensive test plan for deploy.sh and execute all tests.

**Acceptance Criteria:**
- [ ] Create `plans/test-deploy.sh.md` with test structure similar to `test-setup-vps.sh.md`
- [ ] Include tests for all Stories 2.1-2.14
- [ ] Execute all tests against implementation
- [ ] Document any failures and fix implementation
- [ ] All tests pass

**Dependencies:** Complete implementation of deploy.sh
**Priority:** Must-have

---

### Story 6.7: Integration Test Plan Execution
**Description:** Execute all integration tests from Epic 3.

**Acceptance Criteria:**
- [ ] Story 3.1: Full static workflow on fresh VPS
- [ ] Story 3.2: Full dynamic workflow on fresh VPS
- [ ] Story 3.3: Multiple domains on same VPS
- [ ] Story 3.4: Static→Dynamic type change
- [ ] Story 3.5: Dynamic→Static type change
- [ ] Story 3.6: Remove static domain
- [ ] Story 3.7: Remove dynamic domain
- [ ] Story 3.8: Status command comprehensive view
- [ ] All scenarios documented with results
- [ ] Any failures fixed

**Dependencies:** Stories 3.1-3.8, working VPS test environment
**Priority:** Must-have

---

### Story 6.8: Error Scenario Testing
**Description:** Execute all error and edge case tests from Epic 4.

**Acceptance Criteria:**
- [ ] Story 4.1: Invalid SSH key
- [ ] Story 4.2: Non-root deploy user without sudo
- [ ] Story 4.3: Disk full scenario
- [ ] Story 4.4: Network interruption (if testable)
- [ ] Story 4.5: Subdomain configuration
- [ ] Story 4.6: Very long domain name
- [ ] Story 4.7: Port conflict with non-PM2 service
- [ ] Story 4.8: Concurrent execution (document behavior)
- [ ] Story 4.9: Caddy pre-existing
- [ ] Story 4.10: Pre-existing Node.js
- [ ] All scenarios documented, limitations noted

**Dependencies:** Stories 4.1-4.10, controlled test environment
**Priority:** Should-have

---

### Story 6.9: Deployment Scenario Validation
**Description:** Execute all deployment scenario tests from Epic 5.

**Acceptance Criteria:**
- [ ] Story 5.1: Fresh VPS setup (all dependencies)
- [ ] Story 5.2: Incremental domain addition
- [ ] Story 5.3: Registry backup and restore
- [ ] Story 5.4: Caddyfile backup rotation
- [ ] Story 5.5: PM2 process recovery after reboot
- [ ] Story 5.6: SSL certificate renewal (observe over time or simulate)
- [ ] Story 5.7: DNS propagation handling
- [ ] Story 5.8: Rolling back to previous configuration
- [ ] All scenarios documented with procedures

**Dependencies:** Stories 5.1-5.8, working VPS test environment
**Priority:** Must-have

---

## Summary Statistics

- **Total Epics:** 6
- **Total Stories:** 74
- **Must-have:** ~45 stories (blockers for MVP)
- **Should-have:** ~20 stories (important but not blocking)
- **Could-have:** ~9 stories (nice-to-have, edge cases)

---

## Implementation Order Recommendation

1. **Phase 1:** Epic 1 (setup-vps.sh) + Epic 6.1-6.4 (documentation) - Build core provisioning
2. **Phase 2:** Epic 2 (deploy.sh) + Epic 6.6 (deploy test plan) - Build deployment
3. **Phase 3:** Epic 3 (integration) + Epic 6.7 (integration tests) - End-to-end validation
4. **Phase 4:** Epic 4 (error handling) + Epic 6.8 (error tests) - Robustness
5. **Phase 5:** Epic 5 (deployment scenarios) + Epic 6.9 (scenario validation) - Production readiness
6. **Phase 6:** Epic 6.5 (full test plan execution) - Final verification

This structure provides comprehensive coverage of all testing and deployment requirements from the PRD, with clear acceptance criteria and logical dependencies.
