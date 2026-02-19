#!/bin/bash
# Logging functions for setup-vps.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

log_info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warn()    { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error()   { echo -e "${RED}❌${NC} $1"; }
log_step()    { echo -e "\n${CYAN}${BOLD}▸ $1${NC}"; }
