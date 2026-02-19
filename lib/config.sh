#!/bin/bash
# Configuration loading for setup-vps.sh

# SCRIPT_DIR is set by the main script; do not override it
ENV_FILE="${SCRIPT_DIR}/.env.deploy"

# Configuration variables - exported for use in sourced modules
export DRY_RUN=false
export VERBOSE=false
export SUBCOMMAND="setup"

# Determine subcommand: if first arg doesn't start with --, it's a subcommand; otherwise default to "setup"
if [[ -n "${1:-}" ]] && [[ "$1" != --* ]]; then
    SUBCOMMAND="$1"
    shift
else
    SUBCOMMAND="setup"
fi

# Parse options from remaining arguments
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

load_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Configuration file .env.deploy is missing."
        echo ""
        echo "   Copy and customize the example template:"
        echo ""
        echo "     cp .env.deploy.example .env.deploy"
        echo ""
        echo "   Required configuration:"
        echo ""
        echo "     VPS_USER=deploy"
        echo "     VPS_IP=164.90.xxx.xxx"
        echo "     DOMAIN=example.com"
        echo "     DOMAIN_TYPE=static              # static | dynamic"
        echo ""
        echo "   If DOMAIN_TYPE=dynamic, also required:"
        echo ""
        echo "     DOMAIN_PORT=3000                # Local port the app listens on"
        echo ""
        echo "   Optional (with defaults):"
        echo ""
        echo "     # SSH_KEY=~/.ssh/id_ed25519"
        echo "     # SSH_PORT=22"
        echo "     # VPS_BASE_PATH=/var/www"
        echo "     # VPS_APPS_PATH=/home/deploy/apps"
        echo "     # BUILD_CMD=npm run build"
        echo "     # BUILD_OUTPUT=out"
        echo "     # PM2_APP_NAME="
        echo ""
        exit 1
    fi

    # Source the file directly; bash ignores comments and empty lines
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a

    # Required variables
    : "${VPS_USER:?VPS_USER is required in .env.deploy}"
    : "${VPS_IP:?VPS_IP is required in .env.deploy}"
    : "${DOMAIN:?DOMAIN is required in .env.deploy}"
    : "${DOMAIN_TYPE:?DOMAIN_TYPE is required in .env.deploy}"

    # Validate DOMAIN_TYPE
    if [[ "$DOMAIN_TYPE" != "static" ]] && [[ "$DOMAIN_TYPE" != "dynamic" ]]; then
        log_error "DOMAIN_TYPE must be 'static' or 'dynamic'"
        exit 1
    fi

    # Conditional required: DOMAIN_PORT for dynamic
    if [[ "$DOMAIN_TYPE" == "dynamic" ]]; then
        if [[ -z "${DOMAIN_PORT:-}" ]]; then
            log_error "DOMAIN_PORT is required for dynamic domains"
            exit 1
        fi
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

    # Export all configuration variables for use in sourced modules
    export VPS_USER VPS_IP DOMAIN DOMAIN_TYPE DOMAIN_PORT SSH_KEY SSH_PORT
    export VPS_BASE_PATH VPS_APPS_PATH BUILD_CMD BUILD_OUTPUT PM2_APP_NAME
}
