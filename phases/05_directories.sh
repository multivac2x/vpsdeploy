#!/bin/bash
# Phase 5: Directory Setup

phase5_directories() {
    log_step "Phase 5: Directory Setup"

    if [[ "$DOMAIN_TYPE" == "static" ]]; then
        # Static site: deploy to /var/www/domain
        local remote_path="${VPS_BASE_PATH}/${DOMAIN}"
        log_info "Creating static site directory: $remote_path"
        ssh_run "sudo mkdir -p $remote_path"
        ssh_run "sudo chown -R ${VPS_USER}:${VPS_USER} $remote_path"
    else
        # Dynamic app: ensure apps directory exists
        log_info "Ensuring apps directory exists: $VPS_APPS_PATH"
        ssh_run "sudo mkdir -p $VPS_APPS_PATH"
        ssh_run "sudo chown -R ${VPS_USER}:${VPS_USER} $VPS_APPS_PATH"
    fi

    # Ensure Caddy log directory exists with proper permissions
    log_info "Creating Caddy log directory: /var/log/caddy"
    ssh_run "sudo mkdir -p /var/log/caddy"
    ssh_run "sudo chown www-data:www-data /var/log/caddy"
    ssh_run "sudo chmod 755 /var/log/caddy"

    log_success "Directories ready"
}
