# Test Plan for setup-vps.sh

## Overview
This test plan validates the `setup-vps.sh` script's functionality, error handling, and idempotency. The script provisions and configures VPS infrastructure for managing multiple domains (static and dynamic) using Caddy and PM2.

## Prerequisites
- A test VPS accessible via SSH (or use localhost with appropriate setup)
- Bash 4.0+
- jq installed locally for validation
- Test environment variables configured

---

## Test Suite

### 1. SYNTAX & STATIC ANALYSIS

**Test 1.1: Bash Syntax Validation**
```bash
bash -n setup-vps.sh
```
Expected: No output (success)

**Test 1.2: ShellCheck Analysis** (if available)
```bash
shellcheck setup-vps.sh
```
Expected: No warnings or errors

---

### 2. HELP & USAGE

**Test 2.1: Display Help**
```bash
./setup-vps.sh --help
```
Expected: Shows usage information with examples

**Test 2.2: Invalid Option**
```bash
./setup-vps.sh --invalid-option
```
Expected: Error message, exit code 1

---

### 3. CONFIGURATION VALIDATION

**Test 3.1: Missing .env.deploy**
```bash
# Ensure .env.deploy does not exist
rm -f .env.deploy
./setup-vps.sh --dry-run
```
Expected: Error message with instructions to create .env.deploy, exit code 1

**Test 3.2: Empty .env.deploy**
```bash
touch .env.deploy
./setup-vps.sh --dry-run
```
Expected: Error about missing required variables, exit code 1

**Test 3.3: Invalid DOMAIN_TYPE**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=164.90.xxx.xxx
DOMAIN=example.com
DOMAIN_TYPE=invalid
EOF
./setup-vps.sh --dry-run
```
Expected: Error "DOMAIN_TYPE must be 'static' or 'dynamic'", exit code 1

**Test 3.4: Missing DOMAIN_PORT for dynamic**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=164.90.xxx.xxx
DOMAIN=example.com
DOMAIN_TYPE=dynamic
EOF
./setup-vps.sh --dry-run
```
Expected: Error "DOMAIN_PORT is required for dynamic domains", exit code 1

**Test 3.5: Invalid DOMAIN_PORT (out of range)**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=164.90.xxx.xxx
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=99999
EOF
./setup-vps.sh --dry-run
```
Expected: Error "DOMAIN_PORT must be an integer between 1024 and 65535", exit code 1

**Test 3.6: Invalid DOMAIN_PORT (non-numeric)**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=164.90.xxx.xxx
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=abc
EOF
./setup-vps.sh --dry-run
```
Expected: Error about port validation, exit code 1

---

### 4. DRY-RUN MODE TESTS

**Test 4.1: Static Domain Dry-Run**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-static.com
DOMAIN_TYPE=static
EOF
./setup-vps.sh --dry-run --verbose
```
Expected: Shows all commands that would be executed without making changes. Should include:
- SSH connection test
- jq installation check
- Caddy installation check
- UFW configuration
- Registry update (with JSON preview)
- Directory creation
- Caddyfile generation and reload
- Summary with domain status

**Test 4.2: Dynamic Domain Dry-Run**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-dynamic.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
./setup-vps.sh --dry-run --verbose
```
Expected: Similar to static but includes Node.js/PM2 installation checks and PM2 setup phase.

---

### 5. PHASE EXECUTION ORDER

**Test 5.1: Verify Phase Order**
```bash
# Use dry-run with verbose to see phase messages
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-order.com
DOMAIN_TYPE=static
EOF
./setup-vps.sh --dry-run 2>&1 | grep "Phase"
```
Expected output in order:
```
Phase 1: Local Validation
Phase 2: Software Installation
Phase 3: Firewall (UFW)
Phase 4: Registry Update
Phase 5: Directory Setup
Phase 6: Caddy Configuration
Phase 7: PM2 Setup
Phase 8: Summary
```

---

### 6. REGISTRY MANAGEMENT

**Test 6.1: Create New Registry**
```bash
# Clean state: ensure no registry on VPS
# Run with real VPS or mock
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=first-domain.com
DOMAIN_TYPE=static
EOF
./setup-vps.sh --dry-run
```
Expected: Creates registry with version 1, domains object containing first-domain.com

**Test 6.2: Add Second Domain (Merge)**
```bash
# After first domain, add second
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=second-domain.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3001
EOF
./setup-vps.sh --dry-run
```
Expected: Registry should contain both domains with their respective types and ports.

**Test 6.3: Update Existing Domain**
```bash
# Change configuration of existing domain
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=first-domain.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3002
EOF
./setup-vps.sh --dry-run
```
Expected: first-domain.com updated to dynamic with port 3002, second-domain.com unchanged.

**Test 6.4: Port Conflict Detection**
```bash
# Setup: two domains with same port
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=conflict-domain.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
# First, ensure another domain exists with port 3000 in registry
./setup-vps.sh --dry-run 2>&1 | head -20  # May fail if conflict exists
```
Expected: Error "Port conflict: Domain 'existing-domain' already uses port 3000", exit code 1

---

### 7. CADDYFILE GENERATION

**Test 7.1: Static Domain Caddyfile**
```bash
# Generate Caddyfile for static domain and inspect
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=static-test.com
DOMAIN_TYPE=static
EOF
./setup-vps.sh --dry-run 2>&1 | grep -A 50 "Caddyfile"
```
Expected Caddyfile contains:
```
# ── static-test.com (static) ──
www.static-test.com {
    redir https://static-test.com{uri} permanent
}
static-test.com {
    root * /var/www/static-test.com
    file_server
    try_files {path} {path}.html /index.html
    log {
        output file /var/log/caddy/static-test.com.log
        format json
    }
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    encode gzip
}
```

**Test 7.2: Dynamic Domain Caddyfile**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=dynamic-test.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3005
EOF
./setup-vps.sh --dry-run 2>&1 | grep -A 30 "Caddyfile"
```
Expected Caddyfile contains:
```
# ── dynamic-test.com (dynamic, port 3005) ──
www.dynamic-test.com {
    redir https://dynamic-test.com{uri} permanent
}
dynamic-test.com {
    reverse_proxy localhost:3005
    ...
}
```

**Test 7.3: Multiple Domains Caddyfile**
```bash
# Test with registry containing mixed types
# Verify domains appear in sorted order
```
Expected: Domains sorted alphabetically, each with proper configuration.

---

### 8. ERROR HANDLING & ROLLBACK

**Test 8.1: Caddy Validation Failure**
```bash
# Simulate invalid Caddyfile (corrupt registry)
# This would require manual registry manipulation on VPS
# Steps:
# 1. Run setup successfully
# 2. Manually corrupt /etc/caddy/domains.json on VPS
# 3. Run setup-vps.sh again
```
Expected: Script detects invalid JSON, backs it up, creates fresh registry, continues.

**Test 8.2: Caddy Config Validation Failure**
```bash
# After Caddyfile generation, if caddy validate fails
# Script should restore backup and exit with error
```
Expected: Error message, backup restored, exit code 1

**Test 8.3: SSH Connection Failure**
```bash
# Use invalid VPS_IP or stop SSH service
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=test.com
DOMAIN_TYPE=static
EOF
./setup-vps.sh --dry-run
```
Expected: Error "Cannot connect to...", exit code 1

---

### 9. IDEMPOTENCY

**Test 9.1: Repeated Runs (No Changes)**
```bash
# Run setup-vps.sh twice with same configuration
# Second run should report "No Caddy config changes"
```
Expected: Second run shows no changes needed, all phases complete successfully.

**Test 9.2: Registry Preservation**
```bash
# Verify registry timestamps and added_at preserved on updates
```
Expected: `added_at` remains unchanged, only `updated_at` changes.

---

### 10. SUBCOMMANDS

**Test 10.1: Status Command**
```bash
./setup-vps.sh status --dry-run
```
Expected: Shows all domains in registry with their status (without making changes).

**Test 10.2: Remove Command**
```bash
./setup-vps.sh remove --dry-run
```
Expected: Shows what would be removed (registry entry, Caddyfile regeneration, PM2 stop if dynamic).

**Test 10.3: Remove Non-Existent Domain**
```bash
# Ensure domain not in registry
./setup-vps.sh remove --dry-run
```
Expected: Warning "Domain 'X' not found in registry", exit 0.

---

### 11. EDGE CASES

**Test 11.1: Domain with Special Characters**
```bash
# Test with internationalized domain or subdomains
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=sub.example.com
DOMAIN_TYPE=static
EOF
./setup-vps.sh --dry-run
```
Expected: Handles correctly.

**Test 11.2: Very Long Domain Name**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=very-long-subdomain-name-for-testing-edge-cases.example.com
DOMAIN_TYPE=static
EOF
./setup-vps.sh --dry-run
```
Expected: Handles correctly.

**Test 11.3: Port at Boundary (1024, 65535)**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-boundary.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=1024
EOF
./setup-vps.sh --dry-run
# Repeat with 65535
```
Expected: Both valid, no errors.

**Test 11.4: Port Below/Above Range**
```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-invalid.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=80
EOF
./setup-vps.sh --dry-run
```
Expected: Error about port range.

---

### 12. CONCURRENT EXECUTION SAFETY

**Test 12.1: Registry Locking**
```bash
# Not implemented in current script - document as limitation
# Run two instances simultaneously
```
Expected: Potential race condition on registry write. Document that script is not designed for concurrent execution.

---

### 13. LOGGING & OUTPUT

**Test 13.1: Verbose Mode**
```bash
./setup-vps.sh --dry-run --verbose
```
Expected: Shows detailed SSH command output.

**Test 13.2: Color Output**
```bash
# Verify ANSI color codes present in output
./setup-vps.sh --dry-run 2>&1 | grep -q $'\e\[' && echo "Colors enabled"
```
Expected: Color codes present in colored output.

---

## Test Execution Checklist

- [ ] All syntax checks pass
- [ ] Help displays correctly
- [ ] All configuration validation errors work
- [ ] Dry-run mode shows correct commands for both static and dynamic
- [ ] All 8 phases execute in correct order
- [ ] Registry creation, merging, and updating works
- [ ] Port conflict detection works
- [ ] Caddyfile generation is correct for both types
- [ ] Error handling and rollback work
- [ ] Script is idempotent
- [ ] Status and remove subcommands work
- [ ] Edge cases handled properly

---

## Manual Testing on Real VPS

After unit tests pass, perform integration tests on a real or test VPS:

1. **Fresh VPS Setup**
   - Ubuntu 22.04/24.04
   - Non-root user with sudo
   - No Caddy, Node.js, or PM2 installed

2. **Test Static Domain**
   - Configure .env.deploy with static domain
   - Run ./setup-vps.sh
   - Verify Caddy is running
   - Verify domain resolves (DNS pointing to VPS)
   - Check /var/log/caddy/domain.log

3. **Test Dynamic Domain**
   - Configure .env.deploy with dynamic domain
   - Run ./setup-vps.sh
   - Verify Node.js and PM2 installed
   - Deploy Next.js app with ./deploy.sh
   - Verify app is running via PM2
   - Check domain accessibility

4. **Add Second Domain**
   - Run setup-vps.sh with different domain
   - Verify both domains work independently

5. **Remove Domain**
   - Run ./setup-vps.sh remove
   - Verify Caddy config updated
   - Verify domain no longer accessible
   - Verify files remain (as documented)

6. **Status Check**
   - Run ./setup-vps.sh status
   - Verify all domains listed with correct status

---

## Success Criteria

✅ Script passes all syntax checks
✅ All error conditions produce clear, helpful messages
✅ Dry-run mode accurately represents actions
✅ Registry management is correct and idempotent
✅ Caddyfile generation is accurate for all domain types
✅ Script can be safely run multiple times
✅ Subcommands (status, remove) function correctly
✅ Integration on real VPS succeeds for both static and dynamic domains

---

## Notes

- The script requires SSH key-based authentication to the VPS
- DNS must be configured for domains to be accessible
- Port conflicts are only checked for dynamic domains on the same VPS
- The script is NOT designed for concurrent execution
- All changes are logged and backed up (Caddyfile, registry)
