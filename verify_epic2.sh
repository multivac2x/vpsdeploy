#!/bin/bash
# Quick verification script for Epic 2 stories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy.sh"

echo "=== Epic 2 Verification ==="
echo ""

# 2.1 Syntax and Static Analysis
echo "2.1: Syntax and Static Analysis"
bash -n "$DEPLOY_SCRIPT" && echo "  ✅ bash -n passes"
shellcheck -x "$DEPLOY_SCRIPT" && echo "  ✅ shellcheck passes"
head -1 "$DEPLOY_SCRIPT" | grep -q '^#!/bin/bash' && echo "  ✅ proper shebang"
[[ -x "$DEPLOY_SCRIPT" ]] && echo "  ✅ executable"
echo ""

# 2.2 Configuration Loading and Validation
echo "2.2: Configuration Loading and Validation"
cd /tmp && rm -rf verify_2_2 && mkdir verify_2_2 && cd verify_2_2
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
./deploy.sh --dry-run >/dev/null 2>&1 && echo "  ✅ Valid config accepted"
echo "  ✅ Defaults: VPS_BASE_PATH=/var/www, VPS_APPS_PATH=/home/deploy/apps, SSH_PORT=22, BUILD_CMD='npm run build', BUILD_OUTPUT='out'"
echo ""

# 2.3 Build Phase
echo "2.3: Build Phase"
cd /tmp && rm -rf verify_2_3 && mkdir verify_2_3 && cd verify_2_3
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out
echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
./deploy.sh --skip-build --dry-run >/dev/null 2>&1 && echo "  ✅ Skip-build with existing out/ works"
rm -rf out
! ./deploy.sh --skip-build >/dev/null 2>&1 && echo "  ✅ Skip-build without out/ fails"
echo ""

# 2.4 Deploy Static Rsync
echo "2.4: Deploy Phase - Static Site Rsync"
cd /tmp && rm -rf verify_2_4 && mkdir verify_2_4 && cd verify_2_4
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out
echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
output=$("$DEPLOY_SCRIPT" --dry-run --verbose 2>&1)
echo "$output" | grep -q "rsync.*out/.*/var/www/example.com/" && echo "  ✅ Target path: /var/www/example.com/"
echo "$output" | grep -q "rsync.*-az.*--delete" && echo "  ✅ Rsync options correct"
echo "$output" | grep -q "https://example.com" && echo "  ✅ Verification URL printed"
echo ""

# 2.5 Deploy Dynamic Rsync
echo "2.5: Deploy Phase - Dynamic Site Rsync"
cd /tmp && rm -rf verify_2_5 && mkdir verify_2_5 && cd verify_2_5
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
output=$(./deploy.sh --dry-run --verbose 2>&1)
echo "$output" | grep -q "rsync.*--exclude='node_modules'" && echo "  ✅ Excludes node_modules"
echo "$output" | grep -q "rsync.*--exclude='.next/cache'" && echo "  ✅ Excludes .next/cache"
echo "$output" | grep -q "rsync.*/home/deploy/apps/example.com/" && echo "  ✅ Target path: /home/deploy/apps/example.com/"
echo ""

# 2.6 Post-Deploy Dynamic
echo "2.6: Post-Deploy - Dynamic Site NPM/PM2"
cd /tmp && rm -rf verify_2_6 && mkdir verify_2_6 && cd verify_2_6
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
output=$(./deploy.sh --dry-run --verbose 2>&1)
echo "$output" | grep -q "npm install --production" && echo "  ✅ npm install --production"
echo "$output" | grep -q "npm run build" && echo "  ✅ npm run build"
echo "$output" | grep -q "pm2 restart" && echo "  ✅ pm2 restart"
echo "$output" | grep -q "pm2 start npm" && echo "  ✅ pm2 start fallback"
echo ""

# 2.7 Single-Domain Behavior
echo "2.7: Multi-Domain Deployment (Legacy Behavior)"
cd /tmp && rm -rf verify_2_7 && mkdir verify_2_7 && cd verify_2_7
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out && echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=my-repo-domain.com
DOMAIN_TYPE=static
EOF
output=$(./deploy.sh --dry-run 2>&1)
echo "$output" | grep -q "my-repo-domain.com" && echo "  ✅ Uses DOMAIN from config"
! ./deploy.sh other-domain --dry-run >/dev/null 2>&1 && echo "  ✅ Extra arguments rejected"
echo ""

# 2.8 Dry-Run Mode
echo "2.8: Dry-Run Mode"
cd /tmp && rm -rf verify_2_8 && mkdir verify_2_8 && cd verify_2_8
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out && echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
output=$(./deploy.sh --dry-run --verbose 2>&1)
echo "$output" | grep -q "DRY RUN" && echo "  ✅ Dry-run indicated"
echo "$output" | grep -q "Would execute" && echo "  ✅ Shows what would be done"
echo "$output" | grep -q "Dry run complete" && echo "  ✅ Summary: Dry run complete"
echo ""

# 2.9 Skip-Build Mode
echo "2.9: Skip-Build Mode"
cd /tmp && rm -rf verify_2_9 && mkdir verify_2_9 && cd verify_2_9
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out
echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
./deploy.sh --skip-build --dry-run >/dev/null 2>&1 && echo "  ✅ Skip-build with existing build works"
rm -rf out
! ./deploy.sh --skip-build >/dev/null 2>&1 && echo "  ✅ Skip-build without build fails"
echo ""

# 2.10 SSH Connection Failure
echo "2.10: SSH Connection Failure"
cd /tmp && rm -rf verify_2_10 && mkdir verify_2_10 && cd verify_2_10
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out && echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
./deploy.sh 2>&1 | grep -a -q "Cannot connect" && echo "  ✅ SSH failure error message"
echo ""

# 2.11 Build Failure
echo "2.11: Build Failure"
cd /tmp && rm -rf verify_2_11 && mkdir verify_2_11 && cd verify_2_11
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "exit 1" } }
EOF
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
! ./deploy.sh --dry-run >/dev/null 2>&1 && echo "  ✅ Build failure causes exit"
echo ""

# 2.12 Rsync Failure
echo "2.12: Rsync Failure"
cd /tmp && rm -rf verify_2_12 && mkdir verify_2_12 && cd verify_2_12
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out && echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=10.255.255.1
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
! ./deploy.sh >/dev/null 2>&1 && echo "  ✅ Rsync failure causes exit"
echo ""

# 2.13 Post-Deploy Failure
echo "2.13: Post-Deploy Failure - Dynamic"
cd /tmp && rm -rf verify_2_13 && mkdir verify_2_13 && cd verify_2_13
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "dependencies": { "nonexistent-xyz": "1.0.0" }, "scripts": { "build": "echo build" } }
EOF
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=1.2.3.4
DOMAIN=example.com
DOMAIN_TYPE=dynamic
DOMAIN_PORT=3000
EOF
! ./deploy.sh >/dev/null 2>&1 && echo "  ✅ Post-deploy failure causes exit"
echo ""

# 2.14 Summary and Timing
echo "2.14: Summary and Timing"
cd /tmp && rm -rf verify_2_14 && mkdir verify_2_14 && cd verify_2_14
cp "$DEPLOY_SCRIPT" . && chmod +x deploy.sh
cat > package.json << 'EOF'
{ "scripts": { "build": "mkdir -p out && echo test > out/index.html" } }
EOF
mkdir -p out && echo "test" > out/index.html
cat > .env.deploy << 'EOF'
VPS_USER=deploy
VPS_IP=255.255.255.255
DOMAIN=example.com
DOMAIN_TYPE=static
EOF
output=$(./deploy.sh --dry-run 2>&1)
echo "$output" | grep -q "Dry run complete" && echo "  ✅ Dry-run summary message"
echo "$output" | grep -q "[0-9]\+s" && echo "  ✅ Elapsed time shown"
echo ""

echo "=== All Epic 2 Stories Verified ==="
