#!/bin/bash
# Phase 3: Firewall (UFW)

phase3_firewall() {
    log_step "Phase 3: Firewall (UFW)"

    # Check if UFW is installed
    if ! ssh_run "command -v ufw" &>/dev/null; then
        log_info "Installing UFW..."
        ssh_run "sudo apt update && sudo apt install -y ufw"
    fi

    # Configure UFW rules
    log_info "Configuring UFW firewall rules..."

    # Allow SSH
    ssh_run "sudo ufw allow ${SSH_PORT}/tcp"

    # Allow HTTP/HTTPS for Caddy (Caddy will auto-configure but ensure ports are open)
    ssh_run "sudo ufw allow 80/tcp"
    ssh_run "sudo ufw allow 443/tcp"

    # For dynamic domains, allow the domain port if it's not standard
    if [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
        ssh_run "sudo ufw allow ${DOMAIN_PORT}/tcp"
    fi

    # Enable UFW if not already enabled
    if ! ssh_run "sudo ufw status" | grep -q "Status: active"; then
        log_info "Enabling UFW (this may affect existing SSH connections)..."
        ssh_run "echo y | sudo ufw enable"
    fi

    log_success "Firewall configured"
}
