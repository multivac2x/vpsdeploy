#!/bin/bash
# Phase 6: Caddy Configuration

phase6_caddy() {
    log_step "Phase 6: Caddy Configuration"

    local registry_path="/etc/caddy/domains.json"
    local caddyfile_path="/etc/caddy/Caddyfile"

    # Read current registry
    local registry_content
    registry_content=$(ssh_run "sudo cat $registry_path 2>/dev/null || echo '{\"version\":1,\"domains\":{}}'")

    # Generate new Caddyfile
    local new_caddyfile
    new_caddyfile=$(generate_caddyfile "$registry_content")

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would update Caddyfile:"
        echo "$new_caddyfile" | head -20
        [[ $(echo "$new_caddyfile" | wc -l) -gt 20 ]] && echo "  ... (truncated)"
    else
        # Check if existing Caddyfile differs from new one
        local existing_caddyfile
        if ssh_run "test -f $caddyfile_path" &>/dev/null; then
            existing_caddyfile=$(ssh_run "sudo cat $caddyfile_path")
        else
            existing_caddyfile=""
        fi

        if [[ "$existing_caddyfile" == "$new_caddyfile" ]]; then
            log_info "No Caddy config changes detected"
        else
            # Backup existing Caddyfile
            if [[ -n "$existing_caddyfile" ]]; then
                local backup_dir="/etc/caddy/backups"
                ssh_run "sudo mkdir -p $backup_dir"
                local timestamp
                timestamp=$(date +%Y%m%d_%H%M%S)
                local backup_path="${backup_dir}/Caddyfile.${timestamp}"
                echo "$existing_caddyfile" | ssh_run "sudo tee $backup_path > /dev/null"
                log_info "Backed up existing Caddyfile to $backup_path"
            fi

            # Write new Caddyfile
            echo "$new_caddyfile" | ssh_run "sudo tee $caddyfile_path > /dev/null"
            log_success "Caddyfile updated"

            # Validate Caddy configuration
            if ssh_run "caddy validate" &>/dev/null; then
                log_success "Caddy configuration is valid"
            else
                log_error "Caddy configuration validation failed!"
                # Restore the backup
                if [[ -n "$existing_caddyfile" ]]; then
                    log_info "Restoring previous Caddyfile..."
                    echo "$existing_caddyfile" | ssh_run "sudo tee $caddyfile_path > /dev/null"
                    log_success "Previous Caddyfile restored"
                fi
                exit 1
            fi

            # Reload Caddy
            ssh_run "sudo systemctl reload caddy"
            log_success "Caddy reloaded"
        fi
    fi
}
