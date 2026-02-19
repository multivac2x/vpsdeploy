#!/bin/bash
# Phase 2: Software Installation

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
        ssh_run 'curl -1sLf "https://dl.cloudflare.com/caddy/stable/gpg.key" | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg'
        ssh_run 'echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudflare.com/caddy/stable/deb/any-version main" | sudo tee /etc/apt/sources.list.d/caddy-stable.list'
        ssh_run "sudo apt update && sudo apt install -y caddy"
        log_success "Caddy installed"
    fi
    
    # Ensure Caddy service is enabled and running
    if ! ssh_run "systemctl is-enabled caddy" &>/dev/null; then
        log_info "Enabling Caddy service..."
        ssh_run "sudo systemctl enable caddy"
    fi
    if ! ssh_run "systemctl is-active caddy" &>/dev/null; then
        log_info "Starting Caddy service..."
        ssh_run "sudo systemctl start caddy"
    fi
    log_success "Caddy service is active"

    # Check/install Node.js and PM2 (only if ANY domain in registry is dynamic)
    # First, check if registry exists and has any dynamic domains
    local needs_node_pm2=false
    if ssh_run "test -f /etc/caddy/domains.json" &>/dev/null; then
        local dynamic_count
        dynamic_count=$(ssh_run "jq --arg type 'dynamic' '.domains | to_entries[] | select(.value.type == \$type) | .key' /etc/caddy/domains.json 2>/dev/null | wc -l")
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
            ssh_run "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && nvm install --lts"
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
        
        # Configure PM2 startup if not already enabled
        if ! ssh_run "systemctl is-enabled pm2-${VPS_USER}" &>/dev/null; then
            log_info "Configuring PM2 startup..."
            ssh_run "pm2 startup systemd -u ${VPS_USER} --hp /home/${VPS_USER}" 2>/dev/null || true
            log_success "PM2 startup configured"
        else
            log_info "PM2 startup already configured"
        fi
    else
        log_info "No dynamic domains detected, skipping Node.js and PM2 installation"
    fi
}
