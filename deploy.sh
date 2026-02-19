#!/bin/bash
# ============================================
# deploy.sh — Build & Deploy to VPS
# ============================================
# Usage:
#   ./deploy.sh                  # Build and deploy
#   ./deploy.sh --skip-build     # Deploy existing build output without rebuilding
#   ./deploy.sh --dry-run        # Show what would be transferred
#   ./deploy.sh --verbose        # Show detailed rsync output
#   ./deploy.sh --help           # Show usage
#
# This script reads configuration from .env.deploy in the same directory.
# ============================================

set -euo pipefail

# =====================
# CONFIGURATION
# =====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.deploy"

# Parse arguments first to handle --help before requiring config
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            head -20 "$0" | tail -18 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
    esac
done

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    # Create a temporary cleaned env file and source it
    temp_env=$(mktemp)
    grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$' > "$temp_env"
    set -a
    # shellcheck disable=SC1090
    source "$temp_env"
    set +a
    rm -f "$temp_env"
else
    echo -e "\033[0;31m❌\033[0m  Missing .env.deploy file."
    echo ""
    echo "   Create one next to this script with:"
    echo ""
    echo "     VPS_USER=deploy"
    echo "     VPS_IP=164.90.xxx.xxx"
    echo "     DOMAIN=example.com"
    echo "     DOMAIN_TYPE=static              # static | dynamic"
    echo "     # If DOMAIN_TYPE=dynamic:"
    echo "     DOMAIN_PORT=3000"
    echo ""
    exit 1
fi

# Required variables
: "${VPS_USER:?VPS_USER is required in .env.deploy}"
: "${VPS_IP:?VPS_IP is required in .env.deploy}"
: "${DOMAIN:?DOMAIN is required in .env.deploy}"
: "${DOMAIN_TYPE:?DOMAIN_TYPE is required in .env.deploy}"

# Validate DOMAIN_TYPE
if [[ "$DOMAIN_TYPE" != "static" ]] && [[ "$DOMAIN_TYPE" != "dynamic" ]]; then
    echo -e "\033[0;31m❌\033[0m DOMAIN_TYPE must be 'static' or 'dynamic' (got: $DOMAIN_TYPE)"
    exit 1
fi

# Conditional required: DOMAIN_PORT for dynamic
if [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
    : "${DOMAIN_PORT:?DOMAIN_PORT is required for dynamic domains in .env.deploy}"
    if ! [[ "$DOMAIN_PORT" =~ ^[0-9]+$ ]] || [[ "$DOMAIN_PORT" -lt 1024 ]] || [[ "$DOMAIN_PORT" -gt 65535 ]]; then
        echo -e "\033[0;31m❌\033[0m DOMAIN_PORT must be an integer between 1024 and 65535 (got: $DOMAIN_PORT)"
        exit 1
    fi
fi

# Optional variables with defaults
SSH_KEY="${SSH_KEY:-}"
SSH_PORT="${SSH_PORT:-22}"
VPS_BASE_PATH="${VPS_BASE_PATH:-/var/www}"
VPS_APPS_PATH="${VPS_APPS_PATH:-/home/deploy/apps}"
BUILD_CMD="${BUILD_CMD:-npm run build}"
BUILD_OUTPUT="${BUILD_OUTPUT:-out}"
PM2_APP_NAME="${PM2_APP_NAME:-$DOMAIN}"

# =====================
# COLORS & FORMATTING
# =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# =====================
# LOGGING FUNCTIONS
# =====================
log_info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warn()    { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error()   { echo -e "${RED}❌${NC} $1"; }
log_step()    { echo -e "\n${CYAN}${BOLD}▸ $1${NC}"; }

# =====================
# PARSE ARGUMENTS
# =====================
SKIP_BUILD=false
DRY_RUN=false
VERBOSE=false

for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        --dry-run)    DRY_RUN=true ;;
        --verbose)    VERBOSE=true ;;
        --help|-h)
            head -20 "$0" | tail -18 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# =====================
# SSH/RSYNC OPTIONS
# =====================
build_ssh_cmd() {
    local -a cmd
    cmd=(ssh -p "${SSH_PORT}" -o ConnectTimeout=10 -o BatchMode=yes)
    [[ -n "$SSH_KEY" ]] && cmd+=(-i "${SSH_KEY}")
    [[ "$VERBOSE" == true ]] && cmd+=(-v)
    printf '%q ' "${cmd[@]}"
}

RSYNC_OPTS=(-az --delete --stats)
[[ "$VERBOSE" == true ]] && RSYNC_OPTS+=(-v)
[[ "$DRY_RUN" == true ]] && RSYNC_OPTS+=(--dry-run)

# =====================
# BUILD
# =====================
build_site() {
    if [[ "$SKIP_BUILD" == true ]]; then
        log_warn "Skipping build (--skip-build)"
        if [[ ! -d "$BUILD_OUTPUT" ]]; then
            log_error "Build output directory '${BUILD_OUTPUT}/' not found. Run without --skip-build first."
            exit 1
        fi
        return
    fi

    log_step "Building site..."

    if [[ ! -f "package.json" ]]; then
        log_error "No package.json found. Run this script from your Next.js project root."
        exit 1
    fi

    # Run build command
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would run: $BUILD_CMD"
    else
        if ! $BUILD_CMD; then
            log_error "Build failed"
            exit 1
        fi
    fi

    if [[ ! -d "$BUILD_OUTPUT" ]]; then
        log_error "Build output directory '${BUILD_OUTPUT}/' not found after build."
        log_error "Make sure next.config.js has: output: 'export' for static sites"
        exit 1
    fi

    local file_count
    file_count=$(find "$BUILD_OUTPUT" -type f | wc -l)
    log_success "Build complete (${file_count} files)"
}

# =====================
# DEPLOY
# =====================
deploy_static() {
    local domain="$1"
    local remote_path="${VPS_BASE_PATH}/${domain}/"

    log_step "Deploying static site to ${domain}..."

    # Test SSH connection
    if ! eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "echo ok" &>/dev/null; then
        log_error "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
        log_error "Check your SSH key, VPS_USER, VPS_IP, and SSH_PORT settings."
        exit 1
    fi

    # Ensure remote directory exists
    if [[ "$DRY_RUN" == false ]]; then
        eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "mkdir -p '${remote_path}'"
    fi

    # Rsync build output
    log_info "Syncing ${BUILD_OUTPUT}/ → ${remote_path}"
    rsync "${RSYNC_OPTS[@]}" \
        -e "ssh $(build_ssh_cmd)" \
        "${BUILD_OUTPUT}/" \
        "${VPS_USER}@${VPS_IP}:${remote_path}"

    if [[ "$DRY_RUN" == false ]]; then
        log_success "${domain} deployed successfully"
        echo -e "    ${BOLD}Verify:${NC} https://${domain}"
    fi
}

deploy_dynamic() {
    local domain="$1"
    local remote_path="${VPS_APPS_PATH}/${domain}/"

    log_step "Deploying dynamic app to ${domain}..."

    # Test SSH connection
    if ! eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "echo ok" &>/dev/null; then
        log_error "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
        log_error "Check your SSH key, VPS_USER, VPS_IP, and SSH_PORT settings."
        exit 1
    fi

    # Ensure remote directory exists
    if [[ "$DRY_RUN" == false ]]; then
        eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "mkdir -p '${remote_path}'"
    fi

    # Rsync entire project (excluding node_modules, .next/cache)
    log_info "Syncing project → ${remote_path}"
    rsync "${RSYNC_OPTS[@]}" \
        --exclude='node_modules' \
        --exclude='.next/cache' \
        --exclude='.git' \
        -e "ssh $(build_ssh_cmd)" \
        "./" \
        "${VPS_USER}@${VPS_IP}:${remote_path}"

    if [[ "$DRY_RUN" == false ]]; then
        log_success "Code synced"

        # Post-deploy: npm install and build on server
        log_step "Running post-deploy on server..."
        eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "cd '${remote_path}' && npm install --production"

        log_info "Building on server..."
        eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "cd '${remote_path}' && npm run build"

        # Restart PM2
        log_info "Restarting PM2 process..."
        eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "cd '${remote_path}' && pm2 restart '${PM2_APP_NAME}' || pm2 start npm --name '${PM2_APP_NAME}' -- start"
        eval "$(build_ssh_cmd)" "${VPS_USER}@${VPS_IP}" "pm2 save"

        log_success "${domain} deployed and running"
        echo -e "    ${BOLD}Verify:${NC} https://${domain}"
        echo -e "    ${BOLD}PM2 logs:${NC} ssh ${VPS_USER}@${VPS_IP} 'pm2 logs ${PM2_APP_NAME}'"
    fi
}

# =====================
# MAIN
# =====================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  🚀 VPS Deploy Script${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Build
build_site

# Deploy based on type
START_TIME=$(date +%s)

if [[ "$DOMAIN_TYPE" == "static" ]]; then
    deploy_static "$DOMAIN"
else
    deploy_dynamic "$DOMAIN"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$DRY_RUN" == true ]]; then
    log_warn "Dry run complete (${ELAPSED}s)"
else
    log_success "All done! (${ELAPSED}s)"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
