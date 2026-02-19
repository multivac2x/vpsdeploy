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

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library modules
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/ssh.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Source phase functions
source "$SCRIPT_DIR/phases/01_validation.sh"
source "$SCRIPT_DIR/phases/02_software.sh"
source "$SCRIPT_DIR/phases/03_firewall.sh"
source "$SCRIPT_DIR/phases/04_registry.sh"
source "$SCRIPT_DIR/phases/05_directories.sh"
source "$SCRIPT_DIR/phases/06_caddy.sh"
source "$SCRIPT_DIR/phases/07_pm2.sh"
source "$SCRIPT_DIR/phases/08_summary.sh"

# =====================
# HELP
# =====================
show_help() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  🛠  VPS Setup Script${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  ./setup-vps.sh [OPTIONS] [SUBCOMMAND]"
    echo ""
    echo -e "${BOLD}Subcommands:${NC}"
    echo "  setup              Setup or update this domain (default)"
    echo "  status             Show all domains and their status"
    echo "  remove             Remove this domain from the VPS"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  --dry-run          Show what would be done without making changes"
    echo "  --verbose          Show detailed output for all remote commands"
    echo "  --help             Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./setup-vps.sh                    # Setup the domain from .env.deploy"
    echo "  ./setup-vps.sh status             # Show all configured domains"
    echo "  ./setup-vps.sh --dry-run          # Preview changes without applying"
    echo "  ./setup-vps.sh --verbose remove   # Remove domain with detailed output"
    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo "  Place your configuration in .env.deploy file in the same directory."
    echo "  See .env.deploy.example for required variables."
    echo ""
}

# =====================
# ARGUMENT PARSING
# =====================
parse_arguments() {
    local subcommand="setup"
    local dry_run=0
    local verbose=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                show_help
                exit 0
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --verbose)
                verbose="true"
                shift
                ;;
            setup|status|remove)
                subcommand="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done

    # Assign to global variables
    SUBCOMMAND="$subcommand"
    DRY_RUN="$dry_run"
    VERBOSE="$verbose"
}

# Parse arguments first
parse_arguments "$@"

# Export configuration variables for use in sourced modules
export DRY_RUN VERBOSE SUBCOMMAND

# =====================
# MAIN
# =====================
main() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  🛠  VPS Setup Script${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    case "${SUBCOMMAND}" in
        status)
            phase1_validation
            cmd_status
            ;;
        remove)
            phase1_validation
            cmd_remove
            ;;
        setup)
            phase1_validation
            phase2_software
            phase3_firewall
            phase4_registry
            phase5_directories
            phase6_caddy
            phase7_pm2
            phase8_summary
            ;;
    esac
}

main
