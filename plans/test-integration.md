# Integration Test Plan

## Overview
This test plan covers end-to-end integration testing of the complete vps-deploy workflow, combining `setup-vps.sh` and `deploy.sh` for both static and dynamic domains, as well as multi-domain scenarios, type changes, and removals.

## Prerequisites
- A test VPS (Ubuntu 22.04/24.04) with ability to create fresh instances
- SSH key authentication configured
- Local machine with Node.js and npm
- Test domains with DNS pointing to VPS (or use local /etc/hosts for testing)
- All scripts implemented and passing unit tests

---

## Test Suite

### 1. FULL WORKFLOW - STATIC DOMAIN (Story 3.1)

**Test 1.1: Fresh VPS Static Deployment**

```bash
# 1. Create fresh Ubuntu 22.04/24.04 VPS
# 2. Create deploy user with sudo
# 3. Setup SSH key authentication
# 4. Ensure no Caddy, Node.js, PM2, jq installed

# 5. Configure .env.deploy for static domain
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-static.example.com
DOMAIN_TYPE=static
EOF

# 6. Run setup-vps.sh
time ./setup-vps.sh

# 7. Verify Caddy installed and running
ssh deploy@vps "systemctl is-active caddy"  # should be "active"

# 8. Verify registry created
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq .

# 9. Verify directory created
ssh deploy@vps "ls -ld /var/www/test-static.example.com"

# 10. Verify Caddyfile generated
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 10 "test-static.example.com"

# 11. Run deploy.sh
./deploy.sh

# 12. Verify files transferred
ssh deploy@vps "ls -la /var/www/test-static.example.com/"

# 13. Test HTTPS accessibility
curl -I https://test-static.example.com
# Should return 200

# 14. Check SSL certificate
openssl s_client -connect test-static.example.com:443 -servername test-static.example.com 2>/dev/null | openssl x509 -noout -dates
# Should show valid certificate

# 15. Total setup time should be < 10 minutes
```

**Expected Result:** Complete success, site accessible via HTTPS with valid SSL.

---

### 2. FULL WORKFLOW - DYNAMIC DOMAIN (Story 3.2)

**Test 2.1: Fresh VPS Dynamic Deployment**

```bash
# 1. Fresh VPS (or reset previous VPS)
# 2. Configure .env.deploy for dynamic domain
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-dynamic.example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF

# 3. Run setup-vps.sh
time ./setup-vps.sh

# 4. Verify Caddy, Node.js, PM2 installed
ssh deploy@vps "caddy version"
ssh deploy@vps "node --version"
ssh deploy@vps "pm2 --version"

# 5. Verify app directory created
ssh deploy@vps "ls -ld /home/deploy/apps/test-dynamic.example.com"

# 6. Verify Caddyfile has reverse_proxy
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 5 "test-dynamic.example.com"
# Should show: reverse_proxy localhost:3000

# 7. Run deploy.sh (from Next.js project)
./deploy.sh

# 8. Verify code transferred
ssh deploy@vps "ls -la /home/deploy/apps/test-dynamic.example.com/"

# 9. Verify PM2 process running
ssh deploy@vps "pm2 list | grep test-dynamic.example.com"
# Should show: online

# 10. Test HTTPS accessibility
curl -I https://test-dynamic.example.com
# Should return 200

# 11. Check SSL certificate
openssl s_client -connect test-dynamic.example.com:443 -servername test-dynamic.example.com 2>/dev/null | openssl x509 -noout -dates

# 12. Verify post-deploy steps executed
ssh deploy@vps "pm2 logs test-dynamic.example.com --lines 10"
# Should show app startup logs
```

**Expected Result:** Dynamic Next.js app running via PM2, accessible via HTTPS.

---

### 3. MULTIPLE DOMAINS ON SAME VPS (Story 3.3)

**Test 3.1: Adding Multiple Domains Incrementally**

```bash
# Domain A - Static (from repo A)
# Repo A: configure .env.deploy for static-a.example.com
./setup-vps.sh
# Verify domain A in registry
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should include: ["static-a.example.com"]

# Domain B - Static (from repo B)
# Repo B: configure .env.deploy for static-b.example.com
./setup-vps.sh
# Verify both domains in registry
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should include: ["static-a.example.com", "static-b.example.com"]

# Domain C - Dynamic (from repo C)
# Repo C: configure .env.deploy for dynamic-c.example.com (port 3000)
./setup-vps.sh
# Verify all three domains
ssh deploy@vps "sudo jq '.domains | keys' /etc/caddy/domains.json"
# Should include all three

# Deploy each domain
# Repo A: ./deploy.sh
# Repo B: ./deploy.sh
# Repo C: ./deploy.sh

# Verify Caddyfile order (alphabetical)
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -E "^[a-z0-9]+\.example\.com \{" | sed 's/ .*//'
# Should be: dynamic-c.example.com, static-a.example.com, static-b.example.com (alphabetical)

# Test all domains
curl -I https://static-a.example.com
curl -I https://static-b.example.com
curl -I https://dynamic-c.example.com
# All should return 200

# Run status command
./setup-vps.sh status
# Should show all three with correct types and status (✅ for deployed)
```

**Expected Result:** All three domains work independently, Caddyfile sorted alphabetically.

---

### 4. DOMAIN TYPE CHANGES

**Test 4.1: Static → Dynamic (Story 3.4)**

```bash
# Start with static domain already deployed and working
# (From Test 1.1 or existing setup)

# 1. Change .env.deploy to dynamic
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-static.example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3001
EOF

# 2. Run setup-vps.sh
./setup-vps.sh

# 3. Verify registry updated
ssh deploy@vps "sudo jq '.domains[\"test-static.example.com\"]' /etc/caddy/domains.json"
# Should show: type: "dynamic", port: 3001, app_dir: "/home/deploy/apps/test-static.example.com"

# 4. Verify Caddyfile has reverse_proxy
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 5 "test-static.example.com"
# Should show reverse_proxy localhost:3001

# 5. Verify dynamic directory created
ssh deploy@vps "ls -ld /home/deploy/apps/test-static.example.com"

# 6. Deploy dynamic app code
./deploy.sh

# 7. Verify PM2 running
ssh deploy@vps "pm2 list | grep test-static.example.com"
# Should show: online

# 8. Test HTTPS - should serve dynamic app
curl -I https://test-static.example.com

# 9. Check old static files still exist (not deleted)
ssh deploy@vps "ls -ld /var/www/test-static.example.com"
# Should still exist (documented behavior)
```

**Expected Result:** Domain successfully converted to dynamic, old static files preserved.

---

**Test 4.2: Dynamic → Static (Story 3.5)**

```bash
# Start with dynamic domain already running
# (From Test 2.1 or existing setup)

# 1. Change .env.deploy to static
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=your.vps.ip
DOMAIN=test-dynamic.example.com
DOMAIN_TYPE=static
EOF

# 2. Run setup-vps.sh
./setup-vps.sh

# 3. Verify registry updated (no port)
ssh deploy@vps "sudo jq '.domains[\"test-dynamic.example.com\"]' /etc/caddy/domains.json"
# Should show: type: "static", no port field

# 4. Verify PM2 process stopped and deleted
ssh deploy@vps "pm2 list | grep test-dynamic.example.com"
# Should NOT show the process

# 5. Verify Caddyfile has file_server
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep -A 5 "test-dynamic.example.com"
# Should show root * /var/www/test-dynamic.example.com, file_server

# 6. Verify static directory created
ssh deploy@vps "ls -ld /var/www/test-dynamic.example.com"

# 7. Deploy static build
./deploy.sh --skip-build  # or rebuild if needed

# 8. Test HTTPS - should serve static site
curl -I https://test-dynamic.example.com

# 9. Check old app code still exists (not deleted)
ssh deploy@vps "ls -ld /home/deploy/apps/test-dynamic.example.com"
# Should still exist
```

**Expected Result:** Domain successfully converted to static, PM2 stopped, old app code preserved.

---

### 5. DOMAIN REMOVAL

**Test 5.1: Remove Static Domain (Story 3.6)**

```bash
# Ensure static domain is configured and working
./setup-vps.sh status
# Should show static domain with ✅ or ⚠️

# 1. Run remove command
./setup-vps.sh remove
# Should prompt: "Are you sure? (y/N)"
# Answer: y

# 2. Verify domain removed from registry
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq '.domains | keys'
# Should NOT include removed domain

# 3. Verify Caddyfile regenerated without domain
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep "removed-domain.example.com"
# Should not appear

# 4. Test HTTPS - should not resolve
curl -I https://removed-domain.example.com
# Should return error (404, 502, or connection refused)

# 5. Check files still exist (not deleted)
ssh deploy@vps "ls -ld /var/www/removed-domain.example.com"
# Should still exist

# 6. Run status command
./setup-vps.sh status
# Should not show removed domain
```

**Expected Result:** Domain removed from VPS config, files preserved, domain inaccessible.

---

**Test 5.2: Remove Dynamic Domain (Story 3.7)**

```bash
# Ensure dynamic domain is running
./setup-vps.sh status
# Should show dynamic domain with ✅

# 1. Run remove command
./setup-vps.sh remove
# Answer: y to confirmation

# 2. Verify domain removed from registry
ssh deploy@vps "sudo cat /etc/caddy/domains.json" | jq '.domains | keys'

# 3. Verify PM2 process stopped and deleted
ssh deploy@vps "pm2 list | grep removed-domain.example.com"
# Should not show process

# 4. Verify pm2 save was executed (check dump file)
ssh deploy@vps "ls -la ~/.pm2/dump.pm2"

# 5. Verify Caddyfile regenerated and reloaded
ssh deploy@vps "sudo cat /etc/caddy/Caddyfile" | grep "removed-domain.example.com"
# Should not appear

# 6. Test HTTPS - should not resolve
curl -I https://removed-domain.example.com
# Should return error

# 7. Check app code still exists
ssh deploy@vps "ls -ld /home/deploy/apps/removed-domain.example.com"
# Should still exist

# 8. Status command should not show domain
./setup-vps.sh status
```

**Expected Result:** Domain removed, PM2 process deleted, app code preserved.

---

### 6. STATUS COMMAND (Story 3.8)

**Test 6.1: Comprehensive Status View**

```bash
# Setup mixed environment:
# - static-with-files.example.com (has index.html)
# - static-empty.example.com (empty directory)
# - dynamic-online.example.com (PM2 online)
# - dynamic-stopped.example.com (PM2 stopped manually)
# - dynamic-none.example.com (no PM2 process, directory exists)

# For each domain, ensure correct state

# Run status command
./setup-vps.sh status

# Expected output should show:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   🖥  VPS Domain Status (your.vps.ip)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   Domain               Type      Port   Status
#   ─────────────────────────────────────────────────
#   dynamic-online.example.com  dynamic   3000   ✅ Caddy OK, PM2 online
#   dynamic-stopped.example.com dynamic   3001   ❌ PM2 stopped
#   dynamic-none.example.com    dynamic   3002   ⚠️  No PM2 process
#   static-with-files.example.com static    -      ✅ Caddy OK
#   static-empty.example.com     static    -      ⚠️  No index.html
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Caddy service: active (running)
# Disk usage: ...
# Memory: ...
```

**Expected Result:** Accurate status for all domains with appropriate emojis.

---

## Test Execution Checklist

- [ ] Test 1.1: Fresh static workflow passes
- [ ] Test 2.1: Fresh dynamic workflow passes
- [ ] Test 3.1: Multiple domains added incrementally
- [ ] Test 4.1: Static→Dynamic type change
- [ ] Test 4.2: Dynamic→Static type change
- [ ] Test 5.1: Remove static domain
- [ ] Test 5.2: Remove dynamic domain
- [ ] Test 6.1: Status command accurate

---

## Success Criteria

✅ All integration tests pass on fresh VPS
✅ Multiple domains coexist without conflict
✅ Type changes preserve data and update config correctly
✅ Removal cleans up config but preserves files
✅ Status command provides accurate, comprehensive information
✅ SSL certificates obtained automatically
✅ PM2 recovery and startup configured correctly

---

## Notes

- These tests require real VPS instances (or sophisticated mocking)
- DNS must be configured for domains or use /etc/hosts for local testing
- Tests should be run in order to build up state
- After each test, VPS may need to be reset to clean state for next test
- Document any failures and update implementation accordingly
