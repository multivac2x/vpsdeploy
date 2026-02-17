#!/bin/bash
# ============================================
# setup-vps.sh — Provision and configure VPS infrastructure
# ============================================
# Usage:
#   ./setup-vps.sh              # Setup/update this domain on the VPS
#   ./setup-vps.sh status       # Show all domains registered on the VPS
#   ./setup-vps.sh remove       # Remove this repo's domain from the VPS
#
# Options:
#   --dry-run       Show what would be done without making changes
#   --verbose       Show detailed output for all remote commands
#   --help          Show usage information
# ============================================

set -euo pipefail

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
# GLOBAL VARIABLES
# =====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.deploy"

DRY_RUN=false
VERBOSE=false
SUBCOMMAND="${1:-}"

# Shift off subcommand to parse remaining args
if [[ -n "$SUBCOMMAND" ]] && [[ "$SUBCOMMAND" != --* ]]; then
    shift
fi

# Parse options
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --verbose) VERBOSE=true ;;
        --help|-h)
            head -20 "$0" | tail -18 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
    esac
done

# =====================
# LOAD CONFIGURATION
# =====================
load_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Missing .env.deploy file."
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

    # Source the file, ignoring comments and empty lines
    set -a
    source <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')
    set +a

    # Required variables
    : "${VPS_USER:?VPS_USER is required in .env.deploy}"
    : "${VPS_IP:?VPS_IP is required in .env.deploy}"
    : "${DOMAIN:?DOMAIN is required in .env.deploy}"
    : "${DOMAIN_TYPE:?DOMAIN_TYPE is required in .env.deploy}"

    # Validate DOMAIN_TYPE
    if [[ "$DOMAIN_TYPE" != "static" ]] && [[ "$DOMAIN_TYPE" != "dynamic" ]]; then
        log_error "DOMAIN_TYPE must be 'static' or 'dynamic' (got: $DOMAIN_TYPE)"
        exit 1
    fi

    # Conditional required: DOMAIN_PORT for dynamic
    if [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
        : "${DOMAIN_PORT:?DOMAIN_PORT is required for dynamic domains in .env.deploy}"
        # Validate port is a number
        if ! [[ "$DOMAIN_PORT" =~ ^[0-9]+$ ]] || [[ "$DOMAIN_PORT" -lt 1024 ]] || [[ "$DOMAIN_PORT" -gt 65535 ]]; then
            log_error "DOMAIN_PORT must be an integer between 1024 and 65535 (got: $DOMAIN_PORT)"
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
}

# =====================
# SSH EXECUTION HELPERS
# =====================
build_ssh_opts() {
    local opts="-p ${SSH_PORT} -o ConnectTimeout=10 -o BatchMode=yes"
    [[ -n "$SSH_KEY" ]] && opts="${opts} -i ${SSH_KEY}"
    [[ "$VERBOSE" == true ]] && opts="${opts} -v"
    echo "$opts"
}

ssh_run() {
    local ssh_opts
    ssh_opts=$(build_ssh_opts)
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: ssh ${ssh_opts} ${VPS_USER}@${VPS_IP} \"$*\""
    else
        ssh ${ssh_opts} "${VPS_USER}@${VPS_IP}" "$@"
    fi
}

# =====================
# PHASE 1: LOCAL VALIDATION
# =====================
phase1_validation() {
    log_step "Phase 1: Local Validation"

    load_config

    # Test SSH connection
    log_info "Testing SSH connection to ${VPS_USER}@${VPS_IP}:${SSH_PORT}..."
    if ! ssh_run "echo ok" &>/dev/null; then
        log_error "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
        log_error "Check your SSH key, VPS_USER, VPS_IP, and SSH_PORT settings."
        exit 1
    fi
    log_success "SSH connection established"
}

# =====================
# PHASE 2: SOFTWARE INSTALLATION
# =====================
phase2_software() {
    log_step "Phase 2: Software Installation"

    # Check/install jq (always needed)
    if ssh_run "command -v jq" &>/dev/null; then
        local jq_version
        jq_version=$(ssh_run "jq --version" 2>/dev/null || echo "unknown")
        log_success "jq is installed: $jq_version"
    else
        log_info "Installing jq..."
        ssh_run "sudo apt update && sudo apt install -y jq"
        log_success "jq installed"
    fi

    # Check/install Caddy
    if ssh_run "command -v caddy" &>/dev/null; then
        local caddy_version
        caddy_version=$(ssh_run "caddy version" 2>/dev/null | head -1 || echo "unknown")
        log_success "Caddy is installed: $caddy_version"
    else
        log_info "Installing Caddy..."
        ssh_run "sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl"
        ssh_run "curl -1sLf 'https://dl.cloudflare.com/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
        ssh_run "echo \"deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudflare.com/caddy/stable/deb/any-version main\" | sudo tee /etc/apt/sources.list.d/caddy-stable.list"
        ssh_run "sudo apt update && sudo apt install -y caddy"
        log_success "Caddy installed"
    fi

    # Check/install Node.js and PM2 (only if ANY domain in registry is dynamic)
    # First, check if registry exists and has any dynamic domains
    local needs_node_pm2=false
    if ssh_run "test -f /etc/caddy/domains.json" &>/dev/null; then
        local dynamic_count
        dynamic_count=$(ssh_run "jq '.domains | to_entries[] | select(.value.type == \"dynamic\") | .key' /etc/caddy/domains.json 2>/dev/null | wc -l)
        if [[ "$dynamic_count" -gt 0 ]] || [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
            needs_node_pm2=true
        fi
    else
        # No registry yet, check current domain
        if [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
            needs_node_pm2=true
        fi
    fi

    if [[ "$needs_node_pm2" == true ]]; then
        # Check Node.js
        if ssh_run "command -v node" &>/dev/null; then
            local node_version
            node_version=$(ssh_run "node --version" 2>/dev/null || echo "unknown")
            log_success "Node.js is installed: $node_version"
        else
            log_info "Installing Node.js (LTS) via nvm..."
            ssh_run "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
            ssh_run "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\" && nvm install --lts"
            log_success "Node.js installed"
        fi

        # Check PM2
        if ssh_run "command -v pm2" &>/dev/null; then
            local pm2_version
            pm2_version=$(ssh_run "pm2 --version" 2>/dev/null || echo "unknown")
            log_success "PM2 is installed: $pm2_version"
        else
            log_info "Installing PM2..."
            ssh_run "npm install -g pm2"
            log_success "PM2 installed"
        fi
    else
        log_info "No dynamic domains detected, skipping Node.js and PM2 installation"
    fi
}

# =====================
# PHASE 3: FIREWALL
# =====================
phase3_firewall() {
    log_step "Phase 3: Firewall (UFW)"

    # Check if UFW is active
    if ssh_run "sudo ufw status" | grep -q "Status: active"; then
        log_info "UFW is active, checking rules..."

        # Ensure required ports are allowed
        local rules_needed=()
        ssh_run "sudo ufw status numbered" | grep -q "22/tcp" || rules_needed+=("22")
        ssh_run "sudo ufw status numbered" | grep -q "80/tcp" || rules_needed+=("80")
        ssh_run "sudo ufw status numbered" | grep -q "443/tcp" || rules_needed+=("443")

        if [[ ${#rules_needed[@]} -gt 0 ]]; then
            log_info "Adding UFW rules for ports: ${rules_needed[*]}"
            for port in "${rules_needed[@]}"; do
                [[ "$DRY_RUN" == false ]] && ssh_run "sudo ufw allow ${port}/tcp"
            done
        fi
        log_success "Firewall rules are correct"
    else
        log_warn "UFW is not active, enabling with SSH, HTTP, HTTPS..."
        if [[ "$DRY_RUN" == false ]]; then
            ssh_run "sudo ufw allow 22/tcp"
            ssh_run "sudo ufw allow 80/tcp"
            ssh_run "sudo ufw allow 443/tcp"
            ssh_run "sudo ufw --force enable"
        fi
        log_success "UFW enabled"
    fi
}

# =====================
# PHASE 4: REGISTRY UPDATE
# =====================
phase4_registry() {
    log_step "Phase 4: Registry Update"

    local registry_path="/etc/caddy/domains.json"
    local temp_registry="/tmp/domains.json.$$"

    # Read existing registry or create empty
    if ssh_run "test -f $registry_path" &>/dev/null; then
        log_info "Reading existing registry..."
        ssh_run "cp $registry_path $temp_registry" 2>/dev/null || true
    else
        log_info "Creating new registry..."
        echo '{"version":1,"domains":{}}' > "$temp_registry"
    fi

    # Validate JSON if exists
    if [[ -f "$temp_registry" ]]; then
        if ! jq empty "$temp_registry" 2>/dev/null; then
            log_warn "Registry JSON is corrupted, backing up and creating fresh..."
            if [[ "$DRY_RUN" == false ]]; then
                ssh_run "sudo mv $registry_path ${registry_path}.corrupted.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true"
            fi
            echo '{"version":1,"domains":{}}' > "$temp_registry"
        fi
    fi

    # Check for port conflicts if dynamic
    if [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
        local conflicting_domain
        conflicting_domain=$(jq -r --arg port "$DOMAIN_PORT" --arg domain "$DOMAIN" '.domains | to_entries[] | select(.value.type == "dynamic" and .value.port == ($port|tonumber) and .key != $domain) | .key' "$temp_registry" 2>/dev/null || true)
        if [[ -n "$conflicting_domain" ]]; then
            log_error "Port conflict: Domain '$conflicting_domain' already uses port $DOMAIN_PORT"
            exit 1
        fi
    fi

    # Merge/update domain entry
    log_info "Updating registry for domain: $DOMAIN"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Read current registry, update domain, write back
    local updated_json
    if [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
        updated_json=$(jq --arg domain "$DOMAIN" --arg type "$DOMAIN_TYPE" --arg now "$now" --arg port "$DOMAIN_PORT" --arg apps_path "$VPS_APPS_PATH" '
            .domains[$domain] = (
                .domains[$domain] // {}
                | .type = $type
                | .updated_at = $now
                | .port = ($port | tonumber)
                | .app_dir = $apps_path + "/" + $domain
                | if .added_at | not then .added_at = $now else . end
            )
            | .updated_at = $now
        ' "$temp_registry" 2>/dev/null || echo '{"version":1,"domains":{}}')
    else
        updated_json=$(jq --arg domain "$DOMAIN" --arg type "$DOMAIN_TYPE" --arg now "$now" '
            .domains[$domain] = (
                .domains[$domain] // {}
                | .type = $type
                | .updated_at = $now
                | del(.port)
                | del(.app_dir)
                | if .added_at | not then .added_at = $now else . end
            )
            | .updated_at = $now
        ' "$temp_registry" 2>/dev/null || echo '{"version":1,"domains":{}}')
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would update registry:"
        echo "$updated_json" | jq .
    else
        # Upload updated registry
        echo "$updated_json" | ssh_run "sudo tee $registry_path > /dev/null"
        ssh_run "sudo chmod 644 $registry_path"
        log_success "Registry updated"
    fi

    rm -f "$temp_registry"
}

# =====================
# PHASE 5: DIRECTORY SETUP
# =====================
phase5_directories() {
    log_step "Phase 5: Directory Setup"

    if [[ "$DOMAIN_TYPE" == "static" ]]; then
        local target_path="${VPS_BASE_PATH}/${DOMAIN}"
        log_info "Creating static site directory: $target_path"
        if [[ "$DRY_RUN" == false ]]; then
            ssh_run "sudo mkdir -p $target_path"
            ssh_run "sudo chown -R ${VPS_USER}:${VPS_USER} $target_path"
        fi
    else
        local target_path="${VPS_APPS_PATH}/${DOMAIN}"
        log_info "Creating dynamic app directory: $target_path"
        if [[ "$DRY_RUN" == false ]]; then
            ssh_run "sudo mkdir -p $target_path"
            ssh_run "sudo chown -R ${VPS_USER}:${VPS_USER} $target_path"
        fi
    fi

    # Ensure Caddy log directory exists
    log_info "Ensuring /var/log/caddy/ exists"
    if [[ "$DRY_RUN" == false ]]; then
        ssh_run "sudo mkdir -p /var/log/caddy"
        ssh_run "sudo chown -R www-data:www-data /var/log/caddy"
    fi
}

# =====================
# PHASE 6: CADDY CONFIGURATION
# =====================
generate_caddyfile() {
    local registry_content="$1"
    local caddyfile

    caddyfile="# Auto-generated by setup-vps.sh — DO NOT EDIT MANUALLY\n"
    caddyfile+="# Generated: $(date -u +\"%Y-%m-%d %H:%M:%S UTC\")\n\n"

    # Get sorted domain list for deterministic output
    local domains
    domains=$(echo "$registry_content" | jq -r '.domains | keys | sort[]')

    for domain in $domains; do
        local type
        type=$(echo "$registry_content" | jq -r --arg d "$domain" '.domains[$d].type')
        local port
        port=$(echo "$registry_content" | jq -r --arg d "$domain" '.domains[$d].port // empty')

        caddyfile+="# ── $domain ($type"
        [[ -n "$port" ]] && caddyfile+=", port $port"
        caddyfile+=") ──\n"

        # www redirect
        caddyfile+="www.$domain {\n"
        caddyfile+="    redir https://$domain{uri} permanent\n"
        caddyfile+="}\n\n"

        # Main domain block
        caddyfile+="$domain {\n"

        if [[ "$type" == "static" ]]; then
            caddyfile+="    root * /var/www/$domain\n"
            caddyfile+="    file_server\n\n"
            caddyfile+="    try_files {path} {path}.html /index.html\n\n"
        else
            caddyfile+="    reverse_proxy localhost:$port\n\n"
        fi

        caddyfile+="    log {\n"
        caddyfile+="        output file /var/log/caddy/$domain.log\n"
        caddyfile+="        format json\n"
        caddyfile+="    }\n\n"

        caddyfile+="    header {\n"
        caddyfile+="        X-Content-Type-Options \"nosniff\"\n"
        caddyfile+="        X-Frame-Options \"DENY\"\n"
        caddyfile+="        Referrer-Policy \"strict-origin-when-cross-origin\"\n"
        caddyfile+="    }\n\n"

        caddyfile+="    encode gzip\n"
        caddyfile+="}\n\n"
    done

    echo "$caddyfile"
}

phase6_caddy() {
    log_step "Phase 6: Caddy Configuration"

    local registry_path="/etc/caddy/domains.json"
    local caddyfile_path="/etc/caddy/Caddyfile"
    local backup_dir="/etc/caddy/backups"

    # Ensure backup directory exists
    if [[ "$DRY_RUN" == false ]]; then
        ssh_run "sudo mkdir -p $backup_dir"
    fi

    # Fetch current registry
    local registry_content
    registry_content=$(ssh_run "sudo cat $registry_path 2>/dev/null || echo '{\"version\":1,\"domains\":{}}'")

    # Generate new Caddyfile
    local new_caddyfile
    new_caddyfile=$(generate_caddyfile "$registry_content")

    # Get old Caddyfile if exists
    local old_caddyfile
    old_caddyfile=$(ssh_run "sudo cat $caddyfile_path 2>/dev/null || echo ''")

    # Compare
    if [[ "$old_caddyfile" == "$new_caddyfile" ]]; then
        log_success "No Caddy config changes"
    else
        log_info "Caddy config changed, validating and reloading..."

        if [[ "$DRY_RUN" == true ]]; then
            log_info "DRY RUN: Would backup and replace Caddyfile"
            log_info "DRY RUN: Would validate with: caddy validate"
            log_info "DRY RUN: Would reload with: systemctl reload caddy"
            return
        fi

        # Backup old Caddyfile
        if [[ -n "$old_caddyfile" ]]; then
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            local backup_path="${backup_dir}/Caddyfile.${timestamp}"
            ssh_run "sudo cp $caddyfile_path $backup_path"
            log_info "Backed up old Caddyfile to $backup_path"
        fi

        # Write new Caddyfile
        echo "$new_caddyfile" | ssh_run "sudo tee $caddyfile_path > /dev/null"

        # Validate
        if ssh_run "caddy validate" 2>/dev/null; then
            log_success "Caddy config validated"
            ssh_run "sudo systemctl reload caddy"
            log_success "Caddy reloaded"
        else
            log_error "Caddy validation failed! Restoring backup..."
            ssh_run "sudo cp $backup_path $caddyfile_path"
            ssh_run "sudo systemctl reload caddy"
            log_error "Caddy configuration was reverted. Please check your registry."
            exit 1
        fi
    fi
}

# =====================
# PHASE 7: PM2 SETUP
# =====================
phase7_pm2() {
    if [[ "$DOMAIN_TYPE" != "dynamic" ]]; then
        return
    fi

    log_step "Phase 7: PM2 Setup"

    local app_dir="${VPS_APPS_PATH}/${DOMAIN}"

    # Check if PM2 process exists
    if ssh_run "pm2 jlist 2>/dev/null | jq -r '.[] | select(.name == \"$PM2_APP_NAME\") | .name'" | grep -q "$PM2_APP_NAME"; then
        log_info "PM2 process '$PM2_APP_NAME' exists"

        # Check if app directory has package.json
        if ssh_run "test -f $app_dir/package.json" &>/dev/null; then
            log_info "Restarting PM2 process..."
            if [[ "$DRY_RUN" == false ]]; then
                ssh_run "cd $app_dir && pm2 restart $PM2_APP_NAME || pm2 start npm --name '$PM2_APP_NAME' -- start"
            fi
            log_success "PM2 process restarted"
        else
            log_warn "No package.json found in $app_dir"
            log_warn "Deploy your app code first, then run:"
            log_warn "  ssh ${VPS_USER}@${VPS_IP} 'cd $app_dir && pm2 start npm --name \"$PM2_APP_NAME\" -- start'"
        fi
    else
        log_info "PM2 process '$PM2_APP_NAME' does not exist yet"
        log_info "After deploying code, start it with:"
        log_warn "  ssh ${VPS_USER}@${VPS_IP} 'cd $app_dir && pm2 start npm --name \"$PM2_APP_NAME\" -- start'"
    fi

    # Save PM2 list
    if [[ "$DRY_RUN" == false ]]; then
        ssh_run "pm2 save"
    fi

    # Configure PM2 startup if not already
    if ! ssh_run "systemctl is-enabled pm2-$VPS_USER" &>/dev/null; then
        log_info "Configuring PM2 startup..."
        if [[ "$DRY_RUN" == false ]]; then
            ssh_run "pm2 startup systemd -u $VPS_USER --hp /home/$VPS_USER"
        fi
        log_success "PM2 startup configured"
    fi
}

# =====================
# PHASE 8: SUMMARY
# =====================
phase8_summary() {
    log_step "Summary"

    local registry_path="/etc/caddy/domains.json"
    local registry_content
    registry_content=$(ssh_run "sudo cat $registry_path 2>/dev/null || echo '{\"version\":1,\"domains\":{}}'")

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  🖥  VPS Domain Status${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Domain${NC}               ${BOLD}Type${NC}      ${BOLD}Port${NC}   ${BOLD}Status${NC}"
    echo -e "  ─────────────────────────────────────────────────"

    local has_domains=false
    echo "$registry_content" | jq -r '.domains | to_entries[] | .key' | while read -r domain; do
        has_domains=true
        local type
        type=$(echo "$registry_content" | jq -r --arg d "$domain" '.domains[$d].type')
        local port
        port=$(echo "$registry_content" | jq -r --arg d "$domain" '.domains[$d].port // "-"')
        local status="❓ Unknown"

        if [[ "$type" == "static" ]]; then
            # Check if web root has files
            if ssh_run "test -n \$(ls -A /var/www/$domain 2>/dev/null)" &>/dev/null; then
                status="${GREEN}✅ Caddy OK${NC}"
            else
                status="${YELLOW}⚠️  Empty${NC}"
            fi
        else
            # Check PM2 process
            if ssh_run "pm2 jlist 2>/dev/null | jq -r '.[] | select(.name == \"$domain\") | .pm2_env.status'" | grep -q "online"; then
                status="${GREEN}✅ Running${NC}"
            elif ssh_run "pm2 jlist 2>/dev/null | jq -r '.[] | select(.name == \"$domain\") | .pm2_env.status'" | grep -q "stopped"; then
                status="${RED}❌ Stopped${NC}"
            elif ssh_run "pm2 jlist 2>/dev/null | jq -r '.[] | select(.name == \"$domain\") | .pm2_env.status'" | grep -q "errored"; then
                status="${RED}❌ Errored${NC}"
            else
                status="${YELLOW}⚠️  No app${NC}"
            fi
        fi

        printf "  %-23s %-8s %-6s  %s\n" "$domain" "$type" "$port" "$status"
    done

    if [[ "$has_domains" == false ]]; then
        echo "  No domains registered yet."
    fi

    echo -e "${NC}"

    # Caddy service status
    local caddy_status
    caddy_status=$(ssh_run "systemctl is-active caddy" 2>/dev/null || echo "inactive")
    echo -e "  ${BOLD}Caddy:${NC} $caddy_status"

    # Disk usage
    local disk_usage
    disk_usage=$(ssh_run "df -h /var/www 2>/dev/null | tail -1 | awk '{print \$5 \" of \" \$3}'" 2>/dev/null || echo "N/A")
    echo -e "  ${BOLD}Disk (/var/www):${NC} $disk_usage"

    # Memory
    local memory
    memory=$(ssh_run "free -h | awk '/Mem:/ {print \$7 \" free\"}'" 2>/dev/null || echo "N/A")
    echo -e "  ${BOLD}Memory:${NC} $memory"
    echo ""
}

# =====================
# SUBCOMMAND: STATUS
# =====================
cmd_status() {
    log_step "VPS Domain Status"
    phase8_summary
    exit 0
}

# =====================
# SUBCOMMAND: REMOVE
# =====================
cmd_remove() {
    log_step "Removing domain: $DOMAIN"

    local registry_path="/etc/caddy/domains.json"
    local registry_content
    registry_content=$(ssh_run "sudo cat $registry_path 2>/dev/null || echo '{\"version\":1,\"domains\":{}}'")

    # Check if domain exists
    if ! echo "$registry_content" | jq -e --arg d "$DOMAIN" '.domains[$d]' &>/dev/null; then
        log_warn "Domain '$DOMAIN' not found in registry"
        exit 0
    fi

    # Confirm
    echo ""
    echo "This will:"
    echo "  - Remove '$DOMAIN' from the registry"
    echo "  - Regenerate Caddyfile without this domain"
    echo "  - Reload Caddy"
    local type
    type=$(echo "$registry_content" | jq -r --arg d "$DOMAIN" '.domains[$d].type')
    if [[ "$type" == "dynamic" ]]; then
        echo "  - Stop and delete PM2 process '$DOMAIN'"
    fi
    echo ""
    echo -e "  ${YELLOW}Note:${NC} Files at ${VPS_BASE_PATH}/${DOMAIN} or ${VPS_APPS_PATH}/${DOMAIN} will NOT be deleted."
    echo ""
    read -rp "  Continue? (y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        log_info "Cancelled."
        exit 0
    fi

    # Remove from registry
    log_info "Removing domain from registry..."
    local updated_json
    updated_json=$(echo "$registry_content" | jq --arg d "$DOMAIN" 'del(.domains[$d]) | .updated_at = now | .')
    if [[ "$DRY_RUN" == false ]]; then
        echo "$updated_json" | ssh_run "sudo tee $registry_path > /dev/null"
        log_success "Domain removed from registry"
    fi

    # Stop and delete PM2 if dynamic
    if [[ "$type" == "dynamic" ]]; then
        log_info "Stopping PM2 process..."
        if [[ "$DRY_RUN" == false ]]; then
            ssh_run "pm2 delete $DOMAIN 2>/dev/null || true"
            ssh_run "pm2 save"
        fi
        log_success "PM2 process stopped"
    fi

    # Regenerate Caddyfile
    log_info "Regenerating Caddyfile..."
    local new_caddyfile
    new_caddyfile=$(generate_caddyfile "$updated_json")

    local caddyfile_path="/etc/caddy/Caddyfile"
    local backup_dir="/etc/caddy/backups"

    if [[ "$DRY_RUN" == false ]]; then
        ssh_run "sudo mkdir -p $backup_dir"
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="${backup_dir}/Caddyfile.${timestamp}"
        ssh_run "sudo cp $caddyfile_path $backup_path 2>/dev/null || true"
        echo "$new_caddyfile" | ssh_run "sudo tee $caddyfile_path > /dev/null"

        if ssh_run "caddy validate" 2>/dev/null; then
            ssh_run "sudo systemctl reload caddy"
            log_success "Caddy reloaded"
        else
            log_error "Caddy validation failed! Restoring backup..."
            ssh_run "sudo cp $backup_path $caddyfile_path"
            ssh_run "sudo systemctl reload caddy"
            log_error "Failed to remove domain cleanly."
            exit 1
        fi
    else
        log_info "DRY RUN: Would backup, update Caddyfile, validate, and reload"
    fi

    log_success "Domain '$DOMAIN' removed successfully"
    echo ""
    log_info "Files remain at:"
    echo "  - Static: ${VPS_BASE_PATH}/${DOMAIN}"
    echo "  - Dynamic: ${VPS_APPS_PATH}/${DOMAIN}"
    echo ""
    log_info "Remove them manually if desired."
}

# =====================
# MAIN
# =====================
main() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  🛠  VPS Setup Script${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Determine subcommand
    local subcmd="${SUBCOMMAND:-setup}"

    case "$subcmd" in
        status)
            phase1_validation
            cmd_status
            ;;
        remove)
            phase1_validation
            cmd_remove
            ;;
        setup|"")
            phase1_validation
            phase2_software
            phase3_firewall
            phase4_registry
            phase5_directories
            phase6_caddy
            phase7_pm2
            phase8_summary
            ;;
        *)
            log_error "Unknown subcommand: $subcmd"
            echo ""
            echo "Available subcommands:"
            echo "  setup (default)  Setup or update this domain"
            echo "  status           Show all domains and their status"
            echo "  remove           Remove this domain from the VPS"
            echo ""
            echo "Options: --dry-run, --verbose, --help"
            exit 1
            ;;
    esac
}

main
