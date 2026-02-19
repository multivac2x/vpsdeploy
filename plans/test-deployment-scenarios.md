# Deployment Scenarios Test Plan

## Overview
This test plan covers real-world deployment scenarios and operational procedures, including fresh VPS setup, incremental domain addition, backup/restore operations, SSL management, and recovery procedures.

---

## Test Suite

### 1. FRESH VPS SETUP (Story 5.1)

**Test 1.1: Complete Provisioning from Scratch**

```bash
# 1. Create fresh Ubuntu 22.04/24.04 VPS
# 2. Create deploy user with sudo
# 3. Setup SSH key authentication
# 4. Ensure NO software pre-installed (Caddy, Node.js, PM2, jq)

# 5. From project repo, configure .env.deploy
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-fresh.example.com
DOMAIN_TYPE=static
EOF

# 6. Time the setup
time ./setup-vps.sh

# 7. Verify total time < 10 minutes
# (Check the real time output)

# 8. Verify Caddy installed
ssh deploy@vps "caddy version"
# Should show version

# 9. Verify Caddy service running
ssh deploy@vps "systemctl is-active caddy"
# Should be "active"

# 10. Verify jq installed
ssh deploy@vps "jq --version"

# 11. Verify Node.js/PM2 NOT installed (static domain)
ssh deploy@vps "node --version" 2>&1 | grep -i "command not found"
ssh deploy@vps "pm2 --version" 2>&1 | grep -i "command not found"

# 12. Verify UFW configured
ssh deploy@vps "sudo ufw status verbose"
# Should show rules for 22, 80, 443

# 13. Verify directories created
ssh deploy@vps "ls -ld /var/www/test-fresh.example.com"
ssh deploy@vps "ls -ld /var/log/caddy"

# 14. Verify registry created
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq .

# 15. Verify Caddyfile generated
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 10 "test-fresh.example.com"

# 16. Deploy site
./deploy.sh

# 17. Verify files transferred
ssh deploy@vps "ls -la /var/www/test-fresh.example.com/"

# 18. Test HTTPS
curl -I https://test-fresh.example.com
# Should return 200

# 19. Check SSL certificate
openssl s_client -connect test-fresh.example.com:443 -servername test-fresh.example.com 2>/dev/null | openssl x509 -noout -dates
# Should show valid certificate
```

**Expected:** Complete success, all components installed and configured, site accessible.

---

### 2. INCREMENTAL DOMAIN ADDION (Story 5.2)

**Test 2.1: Adding Domains from Different Repos**

```bash
# Scenario: VPS already has domain A configured
# (From previous test or existing setup)

# 1. Verify domain A in registry
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should show: ["domain-a.example.com"]

# 2. From new project repo for domain B (static)
# Copy setup-vps.sh and configure .env.deploy
cp /path/to/vpsdeploy/setup-vps.sh .
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=domain-b.example.com
DOMAIN_TYPE=static
EOF

# 3. Run setup-vps.sh from new repo
./setup-vps.sh --dry-run --verbose
# Should show registry merge

# 4. Execute
./setup-vps.sh

# 5. Verify both domains in registry
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should show: ["domain-a.example.com", "domain-b.example.com"]

# 6. Verify Caddyfile contains both
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -E "^[a-z0-9]+\.example\.com \{" | sed 's/ .*//'
# Should list both in alphabetical order

# 7. Deploy domain B
./deploy.sh

# 8. Verify domain A still works
curl -I https://domain-a.example.com
# Should return 200

# 9. Verify domain B works
curl -I https://domain-b.example.com
# Should return 200

# 10. Run status command
./setup-vps.sh status
# Should show both domains with correct status
```

**Expected:** New domain added seamlessly, existing domains unaffected.

---

### 3. REGISTRY BACKUP AND RESTORE (Story 5.3)

**Test 3.1: Manual Backup and Restore**

```bash
# 1. Backup current registry
ssh deploy@vps "sudo cp /etc/caddy/domains.json /tmp/domains.json.backup"

# 2. Simulate corruption
ssh deploy@vps "echo 'corrupted json' | sudo tee /etc/caddy/domains.json"

# 3. Run setup-vps.sh (any domain)
./setup-vps.sh --dry-run
# Should:
# - Detect invalid JSON
# - Backup corrupted file to .corrupt.TIMESTAMP
# - Create fresh empty registry
# - Add current domain
# - Log warning

# 4. Verify .corrupt backup exists
ssh deploy@vps "ls -l /etc/caddy/domains.json.corrupt.*"

# 5. Verify fresh registry
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq .
# Should show current domain only

# 6. Manual restore: copy backup over
ssh deploy@vps "sudo cp /tmp/domains.json.backup /etc/caddy/domains.json"

# 7. Regenerate Caddyfile from restored registry
./setup-vps.sh

# 8. Verify all domains back in registry
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should show all original domains

# 9. Verify all domains accessible
# Test a few domains with curl
```

**Expected:** Corruption auto-recovered, manual restore works, all domains back online.

---

### 4. CADDYFILE BACKUP ROTATION (Story 5.4)

**Test 4.1: Backup Creation and Retention**

```bash
# 1. Run setup-vps.sh multiple times to generate backups
./setup-vps.sh  # First run - creates initial Caddyfile
./setup-vps.sh  # Second run - may or may not change
./setup-vps.sh  # Third run

# 2. List backups
ssh deploy@vps "ls -l /etc/caddy/backups/"
# Should show multiple timestamped files:
# Caddyfile.20250217_100000
# Caddyfile.20250217_101500
# etc.

# 3. Check backup format
ssh deploy@vps "ls /etc/caddy/backups/" | head -1
# Should match: Caddyfile.YYYYMMDD_HHMMSS

# 4. Check total size (should be small)
ssh deploy@vps "du -sh /etc/caddy/backups/"
# Should be KB range (text files only)

# 5. Manual restore test
# Choose an old backup
OLD_BACKUP=$(ssh deploy@vps "ls /etc/caddy/backups/" | head -1)
ssh deploy@vps "sudo cp /etc/caddy/backups/${OLD_BACKUP} /etc/caddy/Caddyfile"
ssh deploy@vps "sudo caddy validate && sudo systemctl reload caddy"
# Should succeed

# 6. Verify old configuration active
# Test domains that were in that backup
```

**Expected:** Backups created on each change, small size, easy to restore.

---

### 5. PM2 PROCESS RECOVERY (Story 5.5)

**Test 5.1: Reboot Recovery**

```bash
# 1. Ensure dynamic domain is running
./setup-vps.sh status
# Should show dynamic domain with ✅

# 2. Check PM2 process
ssh deploy@vps "pm2 list | grep example.com"
# Should show: online

# 3. Check startup configured
ssh deploy@vps "systemctl is-enabled pm2-deploy"
# Should show: enabled

# 4. Reboot VPS
ssh deploy@vps "sudo reboot"

# 5. Wait for reboot (30-60 seconds)

# 6. Check PM2 service status
ssh deploy@vps "systemctl status pm2-deploy"
# Should show: active (running)

# 7. Check app process
ssh deploy@vps "pm2 list | grep example.com"
# Should show: online

# 8. Test HTTPS
curl -I https://example.com
# Should return 200

# 9. If app not started, try manual resurrect
ssh deploy@vps "pm2 resurrect"
# Document if this is needed
```

**Expected:** PM2 service starts automatically, app comes back online.

---

### 6. SSL CERTIFICATE RENEWAL (Story 5.6)

**Test 6.1: Certificate Inspection and Renewal**

```bash
# 1. Verify domain has SSL certificate
ssh deploy@vps "sudo caddy list-certificates"
# Should show certificate for domain with expiry date

# 2. Check expiry is ~90 days from now
# Use openssl to check exact date
ssh deploy@vps "sudo caddy list-certificates" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}'
# Compare to current date

# 3. Check Caddy logs for renewal activity
ssh deploy@vps "sudo journalctl -u caddy -n 100 | grep -i renew"
# May show past renewals or "certificate is valid"

# 4. Manual renewal test (if cert is already valid, reload won't renew)
ssh deploy@vps "sudo caddy reload"
# Should reload without errors

# 5. Document that Caddy auto-renews ~24h before expiry
# No manual intervention needed
```

**Expected:** SSL managed automatically by Caddy, no cron jobs needed.

---

### 7. DNS PROPAGATION HANDLING (Story 5.7)

**Test 7.1: Setup Before DNS Propagation**

```bash
# 1. Configure domain with A record pointing elsewhere (or not set)
# Check DNS: dig example.com A
# Should NOT point to VPS IP

# 2. Run setup-vps.sh
./setup-vps.sh --dry-run --verbose
# Should succeed, Caddyfile generated

./setup-vps.sh
# Should complete successfully

# 3. Check Caddy is running
ssh deploy@vps "systemctl is-active caddy"
# Should be active

# 4. Check certificate (may not exist yet)
ssh deploy@vps "sudo caddy list-certificates"
# Certificate may not be listed (DNS not pointing yet)

# 5. Deploy code
./deploy.sh
# Should succeed

# 6. Try HTTPS (will fail or show different site)
curl -I https://example.com
# May return 404, 502, or point to old location

# 7. Update DNS to point to VPS IP
# Wait for propagation (check with dig every 30s)

# 8. Once DNS propagates, test HTTPS
curl -I https://example.com
# Should return 200

# 9. Check certificate now exists
ssh deploy@vps "sudo caddy list-certificates"
# Should show certificate

# Document: DNS must propagate before site accessible
```

**Expected:** Setup can run before DNS, site becomes available automatically once DNS propagates.

---

### 8. ROLLBACK PROCEDURE (Story 5.8)

**Test 8.1: Manual Rollback to Backup**

```bash
# 1. List available Caddyfile backups
ssh deploy@vps "ls -l /etc/caddy/backups/"

# 2. Choose a backup from before a problematic change
# e.g., Caddyfile.20250217_100000

# 3. Restore backup
ssh deploy@vps "sudo cp /etc/caddy/backups/Caddyfile.20250217_100000 /etc/caddy/Caddyfile"

# 4. Validate
ssh deploy@vps "sudo caddy validate"
# Should output: "Valid"

# 5. Reload Caddy
ssh deploy@vps "sudo systemctl reload caddy"

# 6. Verify previous configuration is active
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | head -20

# 7. Test domains that were in that backup
curl -I https://old-domain.example.com
# Should work if it was in the backup

# 8. Document this as manual recovery procedure in README
```

**Expected:** Simple rollback using timestamped backups.

---

### 9. MULTIPLE DOMAINS OPERATIONS

**Test 9.1: Mixed Static and Dynamic (Story 3.3)**

```bash
# Setup three domains:
# - static-a.example.com
# - static-b.example.com
# - dynamic-c.example.com (port 3000)

# From each repo, run setup-vps.sh
# Then deploy each

# Verify Caddyfile order (alphabetical)
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -E "^[a-z0-9]+\.example\.com \{" | sed 's/ .*//'
# Should be: dynamic-c, static-a, static-b (alphabetical)

# Test all three domains
curl -I https://static-a.example.com
curl -I https://static-b.example.com
curl -I https://dynamic-c.example.com
# All should return 200

# Run status
./setup-vps.sh status
# Should show all three with correct types
```

**Expected:** Mixed types work together, proper ordering.

---

### 10. DOMAIN TYPE CONVERSIONS

**Test 10.1: Static to Dynamic (Story 3.4)**

```bash
# Start with static domain deployed
./setup-vps.sh status
# Shows static domain

# Change .env.deploy to dynamic
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3001
EOF

# Run setup-vps.sh
./setup-vps.sh

# Verify registry shows dynamic with port
ssh deploy@vps "sudo jq '.domains[\"example.com\"]' /etc/caddy/domains.json"

# Verify Caddyfile has reverse_proxy
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 5 "example.com"

# Verify dynamic directory created
ssh deploy@vps "ls -ld /home/deploy/apps/example.com"

# Deploy dynamic app
./deploy.sh

# Verify PM2 running
ssh deploy@vps "pm2 list | grep example.com"

# Test HTTPS - serves dynamic app
curl -I https://example.com

# Check old static files still exist (not deleted)
ssh deploy@vps "ls -ld /var/www/example.com"
```

**Expected:** Successful conversion, old files preserved.

---

**Test 10.2: Dynamic to Static (Story 3.5)**

```bash
# Start with dynamic domain running
./setup-vps.sh status
# Shows dynamic domain with ✅

# Change .env.deploy to static
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=example.com
DOMAIN_TYPE=static
EOF

# Run setup-vps.sh
./setup-vps.sh

# Verify registry shows static (no port)
ssh deploy@vps "sudo jq '.domains[\"example.com\"]' /etc/caddy/domains.json"

# Verify PM2 stopped and deleted
ssh deploy@vps "pm2 list | grep example.com"
# Should not show process

# Verify Caddyfile has file_server
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 5 "example.com"

# Verify static directory created
ssh deploy@vps "ls -ld /var/www/example.com"

# Deploy static build
./deploy.sh --skip-build  # or rebuild

# Test HTTPS - serves static site
curl -I https://example.com

# Check old app code still exists (not deleted)
ssh deploy@vps "ls -ld /home/deploy/apps/example.com"
```

**Expected:** Successful conversion, PM2 stopped, old app code preserved.

---

### 11. DOMAIN REMOVAL

**Test 11.1: Remove Static Domain (Story 3.6)**

```bash
# Ensure static domain configured and working
./setup-vps.sh status

# Run remove
./setup-vps.sh remove
# Answer 'y' to confirmation

# Verify registry updated
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should NOT include removed domain

# Verify Caddyfile regenerated
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep "removed-domain.example.com"
# Should not appear

# Test HTTPS - should not resolve
curl -I https://removed-domain.example.com
# Should return error

# Check files still exist
ssh deploy@vps "ls -ld /var/www/removed-domain.example.com"
# Should still exist

# Status should not show domain
./setup-vps.sh status
```

**Expected:** Domain removed from config, files preserved.

---

**Test 11.2: Remove Dynamic Domain (Story 3.7)**

```bash
# Ensure dynamic domain running
./setup-vps.sh status
# Shows dynamic domain with ✅

# Run remove
./setup-vps.sh remove
# Answer 'y'

# Verify registry
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"

# Verify PM2 process deleted
ssh deploy@vps "pm2 list | grep removed-domain.example.com"
# Should not show

# Verify pm2 save executed (check dump file)
ssh deploy@vps "ls -la ~/.pm2/dump.pm2"

# Verify Caddyfile updated
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep "removed-domain.example.com"
# Should not appear

# Test HTTPS - should fail
curl -I https://removed-domain.example.com

# Check app code still exists
ssh deploy@vps "ls -ld /home/deploy/apps/removed-domain.example.com"
```

**Expected:** Domain removed, PM2 process deleted, app code preserved.

---

## Test Execution Checklist

- [ ] Test 1.1: Fresh VPS setup completes in < 10 min
- [ ] Test 2.1: Incremental domain addition works
- [ ] Test 3.1: Registry backup/restore successful
- [ ] Test 4.1: Caddyfile backups created and rotatable
- [ ] Test 5.1: PM2 recovers after reboot
- [ ] Test 6.1: SSL certificate auto-renewal verified
- [ ] Test 7.1: DNS propagation handled correctly
- [ ] Test 8.1: Manual rollback procedure works
- [ ] Test 9.1: Mixed static/dynamic domains work
- [ ] Test 10.1: Static→Dynamic conversion successful
- [ ] Test 10.2: Dynamic→Static conversion successful
- [ ] Test 11.1: Static domain removal clean
- [ ] Test 11.2: Dynamic domain removal clean

---

## Success Criteria

✅ Fresh VPS provisioning complete in under 10 minutes
✅ New domains can be added to existing VPS without downtime
✅ Registry and Caddyfile backups are automatic and reliable
✅ PM2 survives reboots (startup configured)
✅ SSL certificates auto-renew seamlessly
✅ DNS propagation does not break setup workflow
✅ Manual rollback is straightforward
✅ Type conversions preserve data
✅ Domain removal cleans config but preserves files

---

## Notes

- These tests require real VPS instances with ability to reboot, modify DNS, etc.
- Document time measurements for key operations
- Verify that all automated backups are created and retained
- Test recovery procedures thoroughly - they are critical for production
- Ensure that file preservation (not auto-deletion) is documented and tested
