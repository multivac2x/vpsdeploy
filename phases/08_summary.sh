#!/bin/bash
# Phase 8: Summary and Subcommands

phase8_summary() {
    log_step "Summary"

    local registry_path="/etc/caddy/domains.json"
    local registry_content
    registry_content=$(ssh_run "sudo cat $registry_path 2>/dev/null || echo '{\"version\":1,\"domains\":{}}'")

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  🖥  VPS Domain Status ($VPS_IP)${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Domain${NC}               ${BOLD}Type${NC}      ${BOLD}Port${NC}   ${BOLD}Status${NC}  ${BOLD}SSL${NC}"
    echo -e "  ────────────────────────────────────────────────────────"

    # Determine if there are any domains
    local domain_count
    domain_count=$(echo "$registry_content" | jq -r '.domains | length')
    local has_domains=false
    [[ "$domain_count" -gt 0 ]] && has_domains=true

    while IFS= read -r domain; do
        local type
        type=$(echo "$registry_content" | jq -r --arg d "$domain" '.domains[$d].type')
        local port
        port=$(echo "$registry_content" | jq -r --arg d "$domain" '.domains[$d].port // "-"')
        local status="❓ Unknown"
        local ssl_status=""

        if [[ "$type" == "static" ]]; then
            # Check if index.html exists
            if ssh_run "test -f /var/www/$domain/index.html" &>/dev/null; then
                status="${GREEN}✅ Caddy OK${NC}"
            elif ssh_run "test -n \$(ls -A /var/www/$domain 2>/dev/null)" &>/dev/null; then
                status="${YELLOW}⚠️  No index.html${NC}"
            else
                status="${YELLOW}⚠️  Empty${NC}"
            fi
        else
            # Check PM2 process
            if ssh_run "pm2 jlist 2>/dev/null | jq -r --arg name \"$domain\" '.[] | select(.name == \$name) | .pm2_env.status'" | grep -q "online"; then
                status="${GREEN}✅ Running${NC}"
            elif ssh_run "pm2 jlist 2>/dev/null | jq -r --arg name \"$domain\" '.[] | select(.name == \$name) | .pm2_env.status'" | grep -q "stopped"; then
                status="${RED}❌ Stopped${NC}"
            elif ssh_run "pm2 jlist 2>/dev/null | jq -r --arg name \"$domain\" '.[] | select(.name == \$name) | .pm2_env.status'" | grep -q "errored"; then
                status="${RED}❌ Errored${NC}"
            else
                status="${YELLOW}⚠️  No app${NC}"
            fi
        fi

        # Check SSL certificate
        if ssh_run "curl -sI https://$domain 2>/dev/null | head -1 | grep -q '200 OK'" &>/dev/null; then
            ssl_status="${GREEN}🔒${NC}"
        else
            ssl_status="${RED}❓${NC}"
        fi

        printf "  %-23s %-8s %-6s  %s  %s\n" "$domain" "$type" "$port" "$status" "$ssl_status"
    done < <(echo "$registry_content" | jq -r '.domains | to_entries[] | .key')

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

cmd_status() {
    log_step "VPS Domain Status"
    phase8_summary
    exit 0
}

cmd_remove() {
    # DOMAIN is set globally from config.sh
    # shellcheck disable=SC2153
    local domain="$DOMAIN"
    log_step "Removing domain: $domain"

    local registry_path="/etc/caddy/domains.json"
    local registry_content
    registry_content=$(ssh_run "sudo cat $registry_path 2>/dev/null || echo '{\"version\":1,\"domains\":{}}'")

    # Check if domain exists
    if ! echo "$registry_content" | jq -e --arg d "$domain" '.domains[$d]' &>/dev/null; then
        log_warn "Domain '$domain' not found in registry"
        exit 0
    fi

    # Confirm
    echo ""
    echo "This will:"
    echo "  - Remove '$domain' from the registry"
    echo "  - Regenerate Caddyfile without this domain"
    echo "  - Reload Caddy"
    local type
    type=$(echo "$registry_content" | jq -r --arg d "$domain" '.domains[$d].type')
    if [[ "$type" == "dynamic" ]]; then
        echo "  - Stop and delete PM2 process '$domain'"
    fi
    echo ""
    echo -e "  ${YELLOW}Note:${NC} Files at ${VPS_BASE_PATH}/${domain} or ${VPS_APPS_PATH}/${domain} will NOT be deleted."
    echo ""
    read -rp "  Continue? (y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        log_info "Cancelled."
        exit 0
    fi

    # Remove from registry
    log_info "Removing domain from registry..."
    local updated_json
    updated_json=$(echo "$registry_content" | jq --arg d "$domain" 'del(.domains[$d]) | .updated_at = now | .')
    if [[ "$DRY_RUN" == false ]]; then
        echo "$updated_json" | ssh_run "sudo tee $registry_path > /dev/null"
        log_success "Domain removed from registry"
    fi

    # Stop and delete PM2 if dynamic
    if [[ "$type" == "dynamic" ]]; then
        log_info "Stopping PM2 process..."
        if [[ "$DRY_RUN" == false ]]; then
            ssh_run "pm2 delete $domain 2>/dev/null || true"
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

    log_success "Domain '$domain' removed successfully"
    echo ""
    log_info "Files remain at:"
    echo "  - Static: ${VPS_BASE_PATH}/${domain}"
    echo "  - Dynamic: ${VPS_APPS_PATH}/${domain}"
    echo ""
    log_info "Remove them manually if desired."
}
