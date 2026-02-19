#!/bin/bash
# Phase 7: PM2 Setup

phase7_pm2() {
    log_step "Phase 7: PM2 Setup"

    # Only needed for dynamic domains
    if [[ "$DOMAIN_TYPE" != "dynamic" ]]; then
        log_info "Skipping PM2 setup (static domain)"
        return
    fi

    local app_dir="${VPS_APPS_PATH}/${DOMAIN}"

    # Check if app code exists locally
    if [[ ! -f "package.json" ]]; then
        log_warn "No local package.json found. App code not deployed yet."
        log_info "After deploying app, manually run: pm2 start npm --name '$PM2_APP_NAME' -- start"
        # Still configure PM2 startup even without app code
        if [[ "$DRY_RUN" == false ]]; then
            log_info "Configuring PM2 startup..."
            if ! ssh_run "systemctl is-enabled pm2-${VPS_USER}" &>/dev/null; then
                ssh_run "pm2 startup systemd -u ${VPS_USER} --hp /home/${VPS_USER}" 2>/dev/null || true
                log_success "PM2 startup configured"
            else
                log_info "PM2 startup already configured"
            fi
            ssh_run "pm2 save" 2>/dev/null || true
        fi
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would deploy app code and start PM2 process"
        return
    fi

    # Deploy app code via rsync
    log_info "Deploying app code to $app_dir..."
    ssh_run "sudo mkdir -p $app_dir"
    local ssh_opts
    ssh_opts=$(build_ssh_opts)
    rsync -az --delete "$ssh_opts" ./ "${VPS_USER}@${VPS_IP}:$app_dir/"

    # Install dependencies
    log_info "Installing dependencies..."
    ssh_run "cd $app_dir && npm install"

    # Check if PM2 process already exists
    local process_exists=false
    if ssh_run "pm2 jlist 2>/dev/null | jq -r --arg name '$PM2_APP_NAME' '.[] | select(.name == \$name) | .name'" | grep -q "$PM2_APP_NAME"; then
        process_exists=true
    fi

    # Start or restart PM2 process
    if [[ "$process_exists" == true ]]; then
        log_info "PM2 process '$PM2_APP_NAME' exists, restarting..."
        ssh_run "pm2 restart $PM2_APP_NAME"
    else
        log_info "Starting PM2 process '$PM2_APP_NAME'..."
        ssh_run "cd $app_dir && pm2 start ecosystem.config.js 2>/dev/null || pm2 start $BUILD_CMD --name $PM2_APP_NAME"
    fi

    # Configure PM2 startup if not already enabled
    if ! ssh_run "systemctl is-enabled pm2-${VPS_USER}" &>/dev/null; then
        log_info "Configuring PM2 startup..."
        ssh_run "pm2 startup systemd -u ${VPS_USER} --hp /home/${VPS_USER}" 2>/dev/null || true
    else
        log_info "PM2 startup already configured"
    fi

    # Save PM2 configuration
    ssh_run "pm2 save"

    # Verify process is online
    local status
    status=$(ssh_run "pm2 jlist 2>/dev/null | jq -r --arg name '$PM2_APP_NAME' '.[] | select(.name == \$name) | .pm2_env.status'" | head -1 || echo "unknown")
    if [[ "$status" == "online" ]]; then
        log_success "PM2 process '$PM2_APP_NAME' is online"
    else
        log_warn "PM2 process status: $status (expected: online)"
    fi
}
