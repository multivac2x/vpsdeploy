# Testing Overview and Master Test Plan

## Introduction

This directory contains comprehensive test plans for the vps-deploy toolkit. The tests are organized by functional area and coverage level, from unit tests to full end-to-end integration scenarios.

---

## Test Plan Structure

### 1. `test-setup-vps.sh.md` - setup-vps.sh Unit Tests
**Coverage:** All 37 stories from Epic 1 (setup-vps.sh Core Functionality)

**Sections:**
- Syntax & Static Analysis
- Help & Usage Display
- Configuration Validation (missing file, invalid values, port validation)
- Dry-Run Mode (static and dynamic)
- Phase Execution Order
- Registry Management (creation, merge, update, port conflicts)
- Caddyfile Generation (static, dynamic, sorting)
- Caddyfile Backup and Validation
- Caddy Reload on Changes
- Directory Setup (static and dynamic)
- PM2 Setup (with/without app code)
- Summary Status Table
- Status Subcommand
- Remove Subcommand (confirmation and execution)
- Idempotency
- SSH Connection Failure
- Registry Corruption Recovery
- Caddy Validation Failure Recovery
- Domain Type Changes (static↔dynamic)
- Software Installation (Caddy, jq, Node.js/PM2 conditional)
- Firewall Configuration (UFW)
- Verbose Mode

**Total Stories:** 37
**Priority:** Must-have for MVP

---

### 2. `test-deploy.sh.md` - deploy.sh Unit Tests
**Coverage:** All 14 stories from Epic 2 (deploy.sh Core Functionality)

**Sections:**
- Syntax & Static Analysis
- Configuration Loading and Validation
- Build Phase (static site, skip-build, errors)
- Deploy Phase - Static Sites (rsync, SSH, paths)
- Deploy Phase - Dynamic Sites (rsync with exclusions)
- Post-Deploy (npm install, build, PM2 restart)
- Multi-Domain Behavior (single-domain pattern)
- Dry-Run Mode
- Skip-Build Mode
- SSH Connection Failure
- Build Failure
- Rsync Failure
- Post-Deploy Failure
- Summary and Timing

**Total Stories:** 14
**Priority:** Must-have for MVP

---

### 3. `test-integration.md` - End-to-End Integration Tests
**Coverage:** All 8 stories from Epic 3 (Integration and End-to-End Testing)

**Sections:**
- Full Workflow - Static Domain (fresh VPS to HTTPS)
- Full Workflow - Dynamic Domain (fresh VPS with PM2)
- Multiple Domains on Same VPS (incremental addition)
- Domain Type Change - Static to Dynamic
- Domain Type Change - Dynamic to Static
- Remove Domain - Static
- Remove Domain - Dynamic
- Status Command - Comprehensive View

**Total Stories:** 8
**Priority:** Must-have for production readiness
**Environment:** Requires real VPS instances

---

### 4. `test-error-handling.md` - Error Scenarios and Edge Cases
**Coverage:** All 10 stories from Epic 4 (Error Handling and Edge Cases)

**Sections:**
- SSH and Connection Errors (invalid key, timeout)
- Configuration Validation (all error types)
- Permission and Privilege Errors (sudo, file permissions)
- Resource Exhaustion (disk full, OOM)
- Network and Communication (interruption, service stopped)
- Data Corruption and Recovery (registry corruption, invalid schema, Caddyfile validation failure)
- Port Conflicts (registry conflict, system-wide port in use)
- Edge Cases (subdomains, long domains, concurrent execution, pre-existing Caddy, pre-existing Node.js)
- Deploy Script Errors (build, rsync, npm, PM2 missing)

**Total Stories:** 10
**Priority:** Should-have for robustness
**Environment:** Requires controlled VPS for failure simulation

---

### 5. `test-deployment-scenarios.md` - Real-World Operations
**Coverage:** All 8 stories from Epic 5 (VPS Deployment Scenarios and Operations)

**Sections:**
- Fresh VPS Setup (complete provisioning, timing)
- Incremental Domain Addition (from different repos)
- Registry Backup and Restore (manual and automatic)
- Caddyfile Backup Rotation (timestamped backups, retention)
- PM2 Process Recovery (reboot survival)
- SSL Certificate Renewal (Let's Encrypt auto-renewal)
- DNS Propagation Handling (setup before DNS points)
- Rolling Back to Previous Configuration (manual rollback)
- Multiple Domains Operations (mixed types)
- Domain Type Conversions (static↔dynamic)
- Domain Removal (cleanup, file preservation)

**Total Stories:** 8
**Priority:** Must-have for production readiness
**Environment:** Requires real VPS with reboot capability

---

## Master Test Execution Checklist

### Phase 1: Unit Tests (Scripts in Isolation)
- [ ] Execute `test-setup-vps.sh.md` - all 37 stories pass
- [ ] Execute `test-deploy.sh.md` - all 14 stories pass
- [ ] Fix any failures before proceeding

### Phase 2: Integration Tests (Real VPS)
- [ ] Execute `test-integration.md` - all 8 stories pass
- [ ] Execute `test-deployment-scenarios.md` - all 8 stories pass
- [ ] Document any environment-specific issues

### Phase 3: Error Handling (Controlled VPS)
- [ ] Execute `test-error-handling.md` - all 10 stories pass
- [ ] Verify error messages are clear and helpful
- [ ] Confirm no data corruption on failures

### Phase 4: Documentation Validation (Epic 6)
- [ ] Story 6.1: `.env.deploy.example` completeness verified
- [ ] Story 6.2: `README.md` accuracy validated
- [ ] Story 6.3: `docs/manual-setup-guide.md` consistency checked
- [ ] Story 6.4: PRD compliance confirmed
- [ ] Story 6.5: All setup-vps tests executed and passing
- [ ] Story 6.6: Deploy test plan created and executed
- [ ] Story 6.7: Integration tests executed
- [ ] Story 6.8: Error scenarios tested
- [ ] Story 6.9: Deployment scenarios validated

---

## Test Environment Requirements

### Minimum VPS Configuration
- **OS:** Ubuntu 22.04 or 24.04
- **CPU:** 1 vCPU minimum (2+ recommended)
- **RAM:** 1GB minimum (2GB recommended)
- **Disk:** 10GB minimum (20GB+ for extensive testing)
- **Network:** Public IP, ports 22, 80, 443 accessible
- **User:** Non-root user with sudo privileges

### Local Machine Requirements
- **OS:** Any with Bash 4.0+
- **Tools:** Node.js, npm, rsync, ssh, jq (for validation)
- **SSH:** Key-based authentication configured to VPS

### Test Domains
- **Option A:** Real domains with DNS pointing to VPS IP
- **Option B:** Local `/etc/hosts` entries for testing (no SSL)
- **Option C:** Wildcard DNS or test domains from provider

---

## Test Execution Strategy

### 1. Automated Tests (Dry-Run)
Most unit tests can be executed in dry-run mode without affecting a real VPS. Use `--dry-run` and `--verbose` flags to verify command construction and logic.

```bash
# Example: test configuration validation
./setup-vps.sh --dry-run 2>&1 | grep "error"
echo $?  # Should be 1 for invalid config
```

### 2. Manual VPS Tests
Integration and deployment scenarios require a real VPS. Best practices:
- Use disposable VPS instances (cloud provider snapshots)
- Reset to clean state between test runs
- Document all steps and observations
- Capture screenshots or logs for evidence

### 3. Error Simulation
For error handling tests, you need to simulate failures:
- **SSH errors:** Invalid key, wrong IP, stop sshd service
- **Permission errors:** Remove user from sudo group, chmod files read-only
- **Disk full:** Fill with dummy files or use quota
- **Network:** Use iptables to drop packets
- **Corruption:** Manually edit registry or Caddyfile to invalid state

---

## Success Criteria

### Must-Have (Blocking MVP)
✅ All 37 setup-vps.sh unit tests pass
✅ All 14 deploy.sh unit tests pass
✅ All 8 integration tests pass on fresh VPS
✅ All 8 deployment scenario tests pass
✅ All 9 documentation validation tests pass

**Total Must-Have Stories:** 76 out of 74 (some overlap)

### Should-Have (Important)
✅ All 10 error handling tests pass
✅ Error messages are clear and actionable
✅ No data corruption in any failure scenario

### Could-Have (Nice to Have)
✅ Concurrent execution behavior documented
✅ Network interruption recovery verified
✅ Very long domain names handled

---

## Test Report Template

For each test story, document:

```markdown
## Story X.Y: Title

**Status:** ✅ Pass / ❌ Fail / ⚠️ Partial
**Date:** YYYY-MM-DD
**Tester:** Name
**Environment:** VPS provider, OS version, domain used

**Steps Executed:**
1. Step 1
2. Step 2
3. ...

**Expected Result:** (from story)
**Actual Result:** (what happened)

**Evidence:**
- Logs: [link or snippet]
- Screenshots: [links]
- Exit codes: [codes]

**Issues Found:**
- None / List any bugs or unexpected behaviors

**Follow-up:**
- None / Need to fix X / Need to retest after Y
```

---

## Known Limitations

1. **Concurrent Execution:** Scripts are NOT thread-safe. Running two instances simultaneously may corrupt the registry. Documented in Story 4.8.

2. **Port Conflict Detection:** Only checks against other domains in the registry, not system-wide port usage. A non-PM2 service could be using the same port. Documented in Story 4.7.

3. **DNS Dependency:** Site is only accessible after DNS propagates. Setup can run before DNS, but HTTPS won't work until A record points to VPS. Documented in Story 5.7.

4. **Registry as Single Source of Truth:** The `/etc/caddy/domains.json` file is the authoritative registry. If it's corrupted, automatic recovery creates a fresh registry (losing all but current domain). Manual restore from backup is required. Documented in Story 1.29.

5. **PM2 Startup:** PM2 startup is configured per-user. If the deploy user's home directory is moved or permissions changed, startup may fail. Documented in Story 5.5.

---

## Maintenance

### When to Update Test Plans
- When adding new features to scripts
- When changing configuration schema
- When fixing bugs that affect behavior
- When adding support for new domain types or deployment modes

### How to Add New Stories
1. Add story file to `docs/stories/` with appropriate number
2. Update relevant test plan in `plans/` to include new story
3. Update `docs/EPICS.md` with new story in appropriate epic
4. Update this overview if structure changes

---

## Quick Reference

| Test Plan | Stories | When to Run |
|-----------|---------|-------------|
| `test-setup-vps.sh.md` | 37 | Every setup-vps.sh change |
| `test-deploy.sh.md` | 14 | Every deploy.sh change |
| `test-integration.md` | 8 | Before release, on fresh VPS |
| `test-deployment-scenarios.md` | 8 | Before release, on test VPS |
| `test-error-handling.md` | 10 | When error handling changes |
| **Total** | **77** | **Full test suite** |

---

## Getting Started

1. **Read the PRD:** `docs/PRD.md` to understand the product
2. **Review Epics:** `docs/EPICS.md` for high-level test coverage
3. **Read Stories:** Individual files in `docs/stories/` for detailed acceptance criteria
4. **Execute Tests:** Follow test plans in `plans/` in order
5. **Document Results:** Use template above for each test
6. **Report Issues:** Create GitHub issues for any failures

---

## Contact

For questions about test plans or to report gaps, please open an issue in the repository.
