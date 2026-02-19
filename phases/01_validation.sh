#!/bin/bash
# Phase 1: Local Validation

phase1_validation() {
    log_step "Phase 1: Local Validation"

    load_config

    # Skip SSH connection test in dry-run mode
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Skipping SSH connection test"
    else
        # Test SSH connection
        log_info "Testing SSH connection to ${VPS_USER}@${VPS_IP}:${SSH_PORT}..."
        if ! ssh_run "echo ok" &>/dev/null; then
            log_error "Cannot connect to ${VPS_USER}@${VPS_IP}:${SSH_PORT}"
            log_error "Check your SSH key, VPS_USER, VPS_IP, and SSH_PORT settings."
            exit 1
        fi
        log_success "SSH connection established"
    fi
}
