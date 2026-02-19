#!/bin/bash
# SSH helper functions for setup-vps.sh

build_ssh_opts() {
    local -a opts
    opts=(-p "${SSH_PORT}" -o ConnectTimeout=10 -o BatchMode=yes)
    [[ -n "$SSH_KEY" ]] && opts+=(-i "${SSH_KEY}")
    [[ "$VERBOSE" == true ]] && opts+=(-v)
    printf '%s\n' "${opts[@]}"
}

ssh_run() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: ssh ${SSH_OPTS:-} ${VPS_USER}@${VPS_IP} \"$*\"" >&2
    else
        # Build full command array
        local -a cmd
        while IFS= read -r opt; do
            cmd+=("$opt")
        done < <(build_ssh_opts)
        cmd+=("${VPS_USER}@${VPS_IP}")
        cmd+=("$@")
        
        if [[ "$VERBOSE" == true ]]; then
            # Show full remote command output
            log_info "REMOTE: $*"
            ssh "${cmd[@]}" 2>&1 | while IFS= read -r line; do
                log_info "REMOTE: $line"
            done
        else
            # Suppress remote output (errors still go to stderr)
            ssh "${cmd[@]}" 2>/dev/null
        fi
    fi
}
