#!/bin/bash
# Comprehensive test script for Epic 2 (deploy.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy.sh"
TEST_DIR="${SCRIPT_DIR}/.test_deploy_tmp"
PASSED=0
FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}✅ PASS${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ FAIL${NC} $1"
    ((FAILED++))
}

section() {
    echo ""
    echo -e "\033[1;36m═══ $1 ═══${NC}"
}

# Setup test environment
setup_test_env() {
    rm -rf "${TEST_DIR}"
    mkdir -p "${TEST_DIR}"
    cd "${TEST_DIR}"
    
    # Create minimal Next.js project structure
    cat > package.json << 'EOF'
{
  "name": "test-app",
  "version": "1.0.0",
  "scripts": {
    "build": "mkdir -p out && echo 'test content' > out/index.html"
  }
}
EOF
}

# Test 2.1: Script Syntax and Static Analysis
test_2_1() {
    section "Story 2.1: Script Syntax and Static Analysis"
    
    # Syntax check
    if bash -n "${DEPLOY_SCRIPT}"; then
        pass "bash -n passes"
    else
        fail "bash -n fails"
    fi
    
    # Shellcheck
    if shellcheck -x "${DEPLOY_SCRIPT}"; then
        pass "shellcheck passes"
    else
        fail "shellcheck fails"
    fi
    
    # Shebang
    if head -1 "${DEPLOY_SCRIPT}" | grep -q '^#!/bin/bash'; then
        pass "Has proper shebang"
    else
        fail "Missing proper shebang"
    fi
    
    # Executable
    if [[ -x "${DEPLOY_SCRIPT}" ]]; then
        pass "Script is executable"
    else
        fail "Script not executable"
    fi
}

# Test 2.2: Configuration Loading and Validation
test_2_2() {
    section "Story 2.2: Configuration Loading and Validation"
    
    cd "${TEST_DIR}"
    
    # Test missing .env.deploy
    rm -f .env.deploy
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Missing .env.deploy causes exit"
    else
        fail "Should exit with missing .env.deploy"
    fi
    
    # Test missing required var (VPS_USER)
    cat > .env.deploy << 'EOF'
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Missing VPS_USER causes exit"
    else
        fail "Should exit with missing VPS_USER"
    fi
    
    # Test invalid DOMAIN_TYPE
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=invalid
EOF
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Invalid DOMAIN_TYPE causes exit"
    else
        fail "Should exit with invalid DOMAIN_TYPE"
    fi
    
    # Test missing DOMAIN_PORT for dynamic
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
EOF
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Missing DOMAIN_PORT for dynamic causes exit"
    else
        fail "Should exit with missing DOMAIN_PORT"
    fi
    
    # Test valid config
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    if "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Valid config accepted"
    else
        fail "Valid config should be accepted"
    fi
    
    # Test optional defaults
    source .env.deploy
    if [[ "${VPS_BASE_PATH:-}" == "/var/www" ]]; then
        pass "VPS_BASE_PATH defaults to /var/www"
    else
        fail "VPS_BASE_PATH default incorrect"
    fi
    if [[ "${VPS_APPS_PATH:-}" == "/home/deploy/apps" ]]; then
        pass "VPS_APPS_PATH defaults to /home/deploy/apps"
    else
        fail "VPS_APPS_PATH default incorrect"
    fi
    if [[ "${SSH_PORT:-}" == "22" ]]; then
        pass "SSH_PORT defaults to 22"
    else
        fail "SSH_PORT default incorrect"
    fi
    if [[ "${BUILD_CMD:-}" == "npm run build" ]]; then
        pass "BUILD_CMD defaults to 'npm run build'"
    else
        fail "BUILD_CMD default incorrect"
    fi
    if [[ "${BUILD_OUTPUT:-}" == "out" ]]; then
        pass "BUILD_OUTPUT defaults to 'out'"
    else
        fail "BUILD_OUTPUT default incorrect"
    fi
}

# Test 2.3: Build Phase
test_2_3() {
    section "Story 2.3: Build Phase - Static Site"
    
    cd "${TEST_DIR}"
    
    # Test package.json exists check
    rm -f package.json
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Missing package.json causes exit"
    else
        fail "Should exit with missing package.json"
    fi
    
    cat > package.json << 'EOF'
{
  "name": "test",
  "scripts": { "build": "echo build" }
}
EOF
    
    # Test build execution
    if "${DEPLOY_SCRIPT}" --dry-run 2>&1 | grep -q "npm run build"; then
        pass "Build command shown in dry-run"
    else
        fail "Build command not shown"
    fi
    
    # Test skip-build with existing out/
    mkdir -p out
    if "${DEPLOY_SCRIPT}" --skip-build --dry-run 2>/dev/null; then
        pass "Skip-build with existing out/ works"
    else
        fail "Skip-build should work with existing out/"
    fi
    
    # Test skip-build without out/
    rm -rf out
    if ! "${DEPLOY_SCRIPT}" --skip-build 2>/dev/null; then
        pass "Skip-build without out/ fails"
    else
        fail "Skip-build without out/ should fail"
    fi
}

# Test 2.4: Deploy Phase - Static Site Rsync
test_2_4() {
    section "Story 2.4: Deploy Phase - Static Site Rsync"
    
    cd "${TEST_DIR}"
    mkdir -p out
    echo "test" > out/index.html
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    
    # Test rsync command format
    if "${DEPLOY_SCRIPT}" --dry-run --verbose 2>&1 | grep -q "rsync.*out/.*deploy@255.255.255.255:/var/www/example.com/"; then
        pass "Rsync command has correct target path"
    else
        fail "Rsync target path incorrect"
    fi
    
    # Test rsync options
    if "${DEPLOY_SCRIPT}" --dry-run --verbose 2>&1 | grep -q "rsync.*-az.*--delete"; then
        pass "Rsync has correct options"
    else
        fail "Rsync options incorrect"
    fi
    
    # Test verification URL
    if "${DEPLOY_SCRIPT}" --dry-run 2>&1 | grep -q "https://example.com"; then
        pass "Verification URL printed"
    else
        fail "Verification URL not printed"
    fi
}

# Test 2.5: Deploy Phase - Dynamic Site Rsync
test_2_5() {
    section "Story 2.5: Deploy Phase - Dynamic Site Rsync"
    
    cd "${TEST_DIR}"
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
    
    # Test rsync command with exclusions
    local output
    output=$("${DEPLOY_SCRIPT}" --dry-run --verbose 2>&1)
    if echo "$output" | grep -q "rsync.*--exclude='node_modules'"; then
        pass "Rsync excludes node_modules"
    else
        fail "Rsync should exclude node_modules"
    fi
    if echo "$output" | grep -q "rsync.*--exclude='.next/cache'"; then
        pass "Rsync excludes .next/cache"
    else
        fail "Rsync should exclude .next/cache"
    fi
    if echo "$output" | grep -q "rsync.*./.*deploy@255.255.255.255:/home/deploy/apps/example.com/"; then
        pass "Rsync target is VPS_APPS_PATH"
    else
        fail "Rsync target should be VPS_APPS_PATH"
    fi
}

# Test 2.6: Post-Deploy - Dynamic Site
test_2_6() {
    section "Story 2.6: Post-Deploy - Dynamic Site NPM/PM2"
    
    cd "${TEST_DIR}"
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
    
    # Test post-deploy commands in dry-run
    local output
    output=$("${DEPLOY_SCRIPT}" --dry-run --verbose 2>&1)
    
    if echo "$output" | grep -q "npm install --production"; then
        pass "Post-deploy includes npm install"
    else
        fail "Post-deploy should include npm install"
    fi
    if echo "$output" | grep -q "npm run build"; then
        pass "Post-deploy includes npm run build"
    else
        fail "Post-deploy should include npm run build"
    fi
    if echo "$output" | grep -q "pm2 restart"; then
        pass "Post-deploy includes pm2 restart"
    else
        fail "Post-deploy should include pm2 restart"
    fi
}

# Test 2.7: Multi-Domain Deployment (Legacy Behavior)
test_2_7() {
    section "Story 2.7: Multi-Domain Deployment (Legacy Behavior)"
    
    cd "${TEST_DIR}"
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=my-repo-domain.com
DOMAIN_TYPE=static
EOF
    
    # Test that it uses DOMAIN from config, not arguments
    local output
    output=$("${DEPLOY_SCRIPT}" --dry-run 2>&1)
    if echo "$output" | grep -q "my-repo-domain.com"; then
        pass "Uses DOMAIN from .env.deploy"
    else
        fail "Should use DOMAIN from config"
    fi
    
    # Test that extra arguments are rejected
    if ! "${DEPLOY_SCRIPT}" other-domain --dry-run 2>/dev/null; then
        pass "Extra domain argument rejected"
    else
        fail "Extra arguments should be rejected"
    fi
}

# Test 2.8: Dry-Run Mode
test_2_8() {
    section "Story 2.8: Dry-Run Mode"
    
    cd "${TEST_DIR}"
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    
    local output
    output=$("${DEPLOY_SCRIPT}" --dry-run --verbose 2>&1)
    
    if echo "$output" | grep -q "DRY RUN"; then
        pass "Dry-run mode indicated"
    else
        fail "Dry-run should be indicated"
    fi
    
    if echo "$output" | grep -q "Would run"; then
        pass "Shows what would be done"
    else
        fail "Should show 'Would run' messages"
    fi
    
    # Note: In current implementation, build still runs in dry-run
    # This needs to be verified against requirements
}

# Test 2.9: Skip-Build Mode
test_2_9() {
    section "Story 2.9: Skip-Build Mode"
    
    cd "${TEST_DIR}"
    mkdir -p out
    echo "test" > out/index.html
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    
    if "${DEPLOY_SCRIPT}" --skip-build --dry-run 2>/dev/null; then
        pass "Skip-build works with existing build"
    else
        fail "Skip-build should work"
    fi
    
    rm -rf out
    if ! "${DEPLOY_SCRIPT}" --skip-build 2>/dev/null; then
        pass "Skip-build fails without build output"
    else
        fail "Skip-build should fail without build output"
    fi
}

# Test 2.10: SSH Connection Failure
test_2_10() {
    section "Story 2.10: SSH Connection Failure"
    
    cd "${TEST_DIR}"
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "SSH failure causes exit"
    else
        fail "Should exit on SSH failure"
    fi
}

# Test 2.11: Build Failure
test_2_11() {
    section "Story 2.11: Build Failure"
    
    cd "${TEST_DIR}"
    cat > package.json << 'EOF'
{
  "name": "test",
  "scripts": { "build": "exit 1" }
}
EOF
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Build failure causes exit"
    else
        fail "Should exit on build failure"
    fi
}

# Test 2.12: Rsync Failure
test_2_12() {
    section "Story 2.12: Rsync Failure"
    
    cd "${TEST_DIR}"
    mkdir -p out
    echo "test" > out/index.html
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=10.255.255.1
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Rsync failure causes exit"
    else
        fail "Should exit on rsync failure"
    fi
}

# Test 2.13: Post-Deploy Failure - Dynamic
test_2_13() {
    section "Story 2.13: Post-Deploy Failure - Dynamic"
    
    cd "${TEST_DIR}"
    cat > package.json << 'EOF'
{
  "name": "test",
  "dependencies": { "nonexistent-package-xyz": "1.0.0" },
  "scripts": { "build": "echo build" }
}
EOF
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
    
    if ! "${DEPLOY_SCRIPT}" --dry-run 2>/dev/null; then
        pass "Post-deploy failure causes exit"
    else
        fail "Should exit on post-deploy failure"
    fi
}

# Test 2.14: Summary and Timing
test_2_14() {
    section "Story 2.14: Summary and Timing"
    
    cd "${TEST_DIR}"
    mkdir -p out
    echo "test" > out/index.html
    
    cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
    
    local output
    output=$("${DEPLOY_SCRIPT}" --dry-run 2>&1)
    
    if echo "$output" | grep -q "Dry run complete"; then
        pass "Dry-run summary message present"
    else
        fail "Dry-run summary missing"
    fi
    
    if echo "$output" | grep -q "[0-9]\+s"; then
        pass "Elapsed time shown"
    else
        fail "Elapsed time not shown"
    fi
}

# Run all tests
main() {
    echo "Testing Epic 2 - deploy.sh Core Functionality"
    echo "=============================================="
    
    test_2_1
    test_2_2
    test_2_3
    test_2_4
    test_2_5
    test_2_6
    test_2_7
    test_2_8
    test_2_9
    test_2_10
    test_2_11
    test_2_12
    test_2_13
    test_2_14
    
    echo ""
    echo "=============================================="
    echo -e "Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
    echo "=============================================="
    
    # Cleanup
    cd "${SCRIPT_DIR}"
    rm -rf "${TEST_DIR}"
    
    return $((FAILED > 0 ? 1 : 0))
}

main
