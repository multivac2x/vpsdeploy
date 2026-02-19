# Error Handling and Edge Cases Test Plan

## Overview
This test plan focuses on error conditions, edge cases, and exceptional scenarios to ensure the scripts handle failures gracefully and recover appropriately.

---

## Test Suite

### 1. SSH AND CONNECTION ERRORS

**Test 1.1: Invalid SSH Key (Story 4.1)**

```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=example.com
DOMAIN_TYPE=static
SSH_KEY=/nonexistent/key.pem
EOF

./setup-vps.sh --dry-run
echo $?  # Should be 1

# Output should contain:
# "Cannot connect to deploy@your.vps.ip:22"
# "Check your SSH key, VPS_USER, VPS_IP, and SSH_PORT settings."
```

**Expected:** Clear error, no changes made.

---

**Test 1.2: SSH Connection Timeout (Story 1.28)**

```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=192.0.2.1  # TEST-NET-1, unroutable
DOMAIN=example.com
DOMAIN_TYPE=static
EOF

./setup-vps.sh --dry-run
echo $?  # Should be 1
```

**Expected:** Connection attempt times out after 10s, error message.

---

### 2. CONFIGURATION VALIDATION

**Test 1.3: All Validation Errors (Stories 1.3-1.6, 2.2)**

```bash
# Missing .env.deploy
rm -f .env.deploy
./setup-vps.sh --dry-run
# Exit 1, shows template

# Empty .env.deploy
touch .env.deploy
./setup-vps.sh --dry-run
# Exit 1, missing vars error

# Invalid DOMAIN_TYPE
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=foo
EOF
./setup-vps.sh --dry-run
# Exit 1, "must be 'static' or 'dynamic'"

# Missing DOMAIN_PORT for dynamic
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
EOF
./setup-vps.sh --dry-run
# Exit 1, "DOMAIN_PORT is required"

# Invalid port (too low)
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=80
EOF
./setup-vps.sh --dry-run
# Exit 1, "must be an integer between 1024 and 65535"

# Invalid port (non-numeric)
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=abc
EOF
./setup-vps.sh --dry-run
# Exit 1, port validation error
```

**Expected:** All validation errors produce clear, specific messages and exit code 1.

---

### 3. PERMISSION AND PRIVILEGE ERRORS

**Test 2.1: Deploy User Without Sudo (Story 4.2)**

```bash
# On VPS, ensure deploy user is NOT in sudo group
# Then run setup-vps.sh on fresh VPS

./setup-vps.sh --dry-run --verbose
# Should fail when attempting sudo
# Error: "User does not have sudo privileges"
# Suggests: sudo usermod -aG sudo deploy
# Exit 1
```

**Expected:** Clear error about sudo privileges.

---

**Test 2.2: Registry Write Permission Denied**

```bash
# On VPS, make registry read-only
ssh deploy@vps "sudo chmod 444 /etc/caddy/domains.json"

./setup-vps.sh --dry-run
# Should fail when trying to write registry
# Error message about permission denied
# Exit 1

# Restore permissions after test
ssh deploy@vps "sudo chmod 644 /etc/caddy/domains.json"
```

**Expected:** Clear permission error.

---

### 4. RESOURCE EXHAUSTION

**Test 3.1: Disk Full During Rsync (Story 4.3)**

```bash
# On VPS, fill disk or set quota
# e.g., dd if=/dev/zero of=/tmp/fill bs=1M count=9000  # Fill 9GB

./deploy.sh
# Rsync should fail with "No space left on device"
# Script exits with rsync error
# Exit code non-zero
```

**Expected:** Rsync error propagated, no partial deployment.

---

**Test 3.2: Out of Memory During Build**

```bash
# Simulate by limiting memory or using huge project
# Build should fail with OOM or exit code non-zero

./deploy.sh
# Build failure should stop script before deploy
# Exit code reflects build failure
```

**Expected:** Build failure stops execution.

---

### 5. NETWORK AND COMMUNICATION

**Test 4.1: Network Interruption During Rsync (Story 4.4)**

```bash
# Use tc or iptables to drop packets during transfer
# e.g., on VPS: iptables -A INPUT -p tcp --dport 22 -j DROP

./deploy.sh
# Should fail with network error
# Exit non-zero

# Remove rule and retry
# Should succeed on retry (rsync resumable)
```

**Expected:** Network failure handled, retry works.

---

**Test 4.2: SSH Service Stopped**

```bash
# On VPS: sudo systemctl stop sshd

./setup-vps.sh --dry-run
# Connection refused
# Exit 1

# Restart sshd after test
```

**Expected:** Connection error, clear message.

---

### 6. DATA CORRUPTION AND RECOVERY

**Test 5.1: Corrupted Registry (Story 1.29)**

```bash
# Corrupt registry
ssh deploy@vps "echo 'not valid json' | sudo tee /etc/caddy/domains.json"

./setup-vps.sh --dry-run
# Should:
# - Backup corrupted file to /etc/caddy/domains.json.corrupt.TIMESTAMP
# - Create fresh empty registry
# - Add current domain
# - Log warning
# - Continue successfully

# Verify backup exists
ssh deploy@vps "ls -l /etc/caddy/domains.json.corrupt.*"

# Verify fresh registry
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq .
# Should show version 1, empty domains, plus current domain added
```

**Expected:** Automatic recovery with backup.

---

**Test 5.2: Invalid Registry Schema**

```bash
# Create registry with missing required fields
ssh deploy@vps "sudo tee /etc/caddy/domains.json << 'EOF'
{
  "domains": {}
}
EOF"

./setup-vps.sh --dry-run
# Should handle missing version/updated_at
# Either fix it or recreate fresh

# Check resulting registry is valid
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq .
```

**Expected:** Handles schema issues gracefully.

---

**Test 5.3: Caddyfile Validation Failure (Story 1.30)**

```bash
# Corrupt registry to cause invalid Caddyfile
# e.g., set port to string instead of number
ssh deploy@vps "sudo jq '.domains[\"example.com\"].port = \"abc\"' /etc/caddy/domains.json > tmp && sudo mv tmp /etc/caddy/domains.json"

./setup-vps.sh --dry-run
# Should:
# - Generate Caddyfile (invalid)
# - Run caddy validate → fails
# - Backup invalid Caddyfile
# - Restore previous Caddyfile from backup
# - Exit with error
# - Old Caddyfile remains active

# Verify old Caddyfile restored
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep "reverse_proxy"
# Should show valid config (previous one)
```

**Expected:** Rollback on validation failure, VPS remains functional.

---

### 7. PORT CONFLICTS

**Test 6.1: Port Conflict Detection (Story 1.13)**

```bash
# Ensure domain A with port 3000 exists in registry
# Then try to add domain B with same port

cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=conflict-test.example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF

./setup-vps.sh --dry-run
echo $?  # Should be 1

# Error should mention port conflict and conflicting domain
# Registry should be unchanged
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should NOT include conflict-test.example.com
```

**Expected:** Clear error, no partial changes.

---

**Test 6.2: Port Already Used by Non-PM2 Service (Story 4.7)**

```bash
# On VPS, start a service on port 3000 (not PM2)
# e.g., python3 -m http.server 3000 &

# Then run setup-vps.sh with DOMAIN_PORT=3000
# Should succeed (no registry conflict)
# But PM2 start may fail if port actually in use

./setup-vps.sh
# May show PM2 start failure later
```

**Expected:** Script doesn't check system-wide ports, only registry. PM2 may fail.

---

### 8. EDGE CASES

**Test 7.1: Domain with Subdomain (Story 4.5)**

```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=app.test.example.com
DOMAIN_TYPE=static
EOF

./setup-vps.sh --dry-run --verbose
# Should handle full subdomain correctly

# Check paths in output
# Should show: /var/www/app.test.example.com/
# Should show: www.app.test.example.com redirect
```

**Expected:** Subdomains handled correctly.

---

**Test 7.2: Very Long Domain Name (Story 4.6)**

```bash
# 63-character subdomain label
LONG_SUBDOMAIN=$(printf 'a%.0s' {1..63})
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=${LONG_SUBDOMAIN}.example.com
DOMAIN_TYPE=static
EOF

./setup-vps.sh --dry-run --verbose
# Should handle without truncation or line wrapping issues
```

**Expected:** Long domains work correctly.

---

**Test 7.3: Concurrent Execution (Story 4.8)**

```bash
# Start two instances simultaneously
./setup-vps.sh &
./setup-vps.sh &

wait

# Check registry
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq .

# May show:
# - Corrupted JSON
# - Lost updates
# - Race condition artifacts

# Document observed behavior
# Conclusion: NOT safe for concurrent execution
```

**Expected:** Registry may corrupt, document limitation.

---

**Test 7.4: Caddy Already Installed with Custom Config (Story 4.9)**

```bash
# On VPS, manually create custom Caddyfile
sudo tee /etc/caddy/Caddyfile << 'EOF'
# Custom manual config
example.com {
    respond "Hello from manual config"
}
EOF

./setup-vps.sh --dry-run --verbose
# Should show backup being created

./setup-vps.sh

# Check backup exists
ssh deploy@vps "ls /etc/caddy/backups/"
# Should show timestamped backup

# New Caddyfile should be generated from registry
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 5 "example.com"
# Should show proper config, not "Hello from manual config"
```

**Expected:** Backup created, custom config replaced.

---

**Test 7.5: Pre-existing Node.js (Non-nvm) (Story 4.10)**

```bash
# On VPS, install Node.js via nodesource
# e.g., curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
# sudo apt install -y nodejs

./setup-vps.sh --dry-run --verbose
# Should detect Node.js is installed
# Skip nvm installation
# Proceed with PM2 check/install

# Verify node --version works
ssh deploy@vps "node --version"
```

**Expected:** No nvm install, Node.js detected.

---

### 9. DEPLOY SCRIPT ERRORS

**Test 8.1: Build Failure (Story 2.11)**

```bash
# Introduce error in Next.js config
cat > next.config.js << 'EOF'
invalid json
EOF

cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=example.com
DOMAIN_TYPE=static
EOF

./deploy.sh
echo $?  # Should be non-zero (build failure)
# Should not attempt rsync
```

**Expected:** Build failure stops execution.

---

**Test 8.2: Rsync Failure (Story 2.12)**

```bash
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=10.255.255.1  # Unroutable
DOMAIN=example.com
DOMAIN_TYPE=static
EOF

./deploy.sh
echo $?  # Non-zero
# Error should include rsync output
```

**Expected:** Rsync error propagated.

---

**Test 8.3: Post-Deploy NPM Install Failure (Story 2.13)**

```bash
# Create package.json with invalid dependency
cat > package.json << 'EOF'
{
  "name": "test",
  "version": "1.0.0",
  "dependencies": {
    "nonexistent-package-xyz": "1.0.0"
  },
  "scripts": {
    "build": "echo build"
  }
}
EOF

cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF

./deploy.sh
echo $?  # Non-zero (npm install failure)
# Should not attempt PM2 restart
```

**Expected:** NPM failure stops execution.

---

**Test 8.4: PM2 Not Installed on VPS**

```bash
# On VPS, uninstall PM2
ssh deploy@vps "npm uninstall -g pm2"

./deploy.sh
# Post-deploy should fail on pm2 command
# Error message about PM2
# Exit non-zero
```

**Expected:** Clear error about PM2 not found.

---

## Test Execution Checklist

- [ ] All SSH/connection error tests pass
- [ ] All configuration validation tests pass
- [ ] Permission errors handled correctly
- [ ] Resource exhaustion (disk, memory) handled
- [ ] Network interruption handled
- [ ] Data corruption recovery works (registry, Caddyfile)
- [ ] Port conflict detection works
- [ ] All edge cases (subdomains, long domains, concurrent) documented
- [ ] Pre-existing software (Node.js) detected correctly
- [ ] Deploy script errors (build, rsync, npm) handled gracefully

---

## Success Criteria

✅ All error conditions produce clear, actionable error messages
✅ No data corruption on failures
✅ Registry corruption auto-recovers with backup
✅ Caddyfile validation failures rollback safely
✅ Script exits with appropriate non-zero codes on errors
✅ Edge cases documented and handled appropriately
✅ Concurrent execution documented as unsupported

---

## Notes

- Some tests require controlled VPS environment (ability to simulate failures)
- Document any unexpected behaviors
- Error messages should be user-friendly and suggest fixes
- Always verify VPS remains functional after errors
