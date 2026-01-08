#!/bin/bash
# ==============================================================================
# Script Name: update-deps.sh
# Description: Interactive dependency updater for Bun projects.
#              Runs validation with error reporting.
# Usage:       ./scripts/update-deps.sh [-y|--yes]
# ==============================================================================

set -e
set -o pipefail

# --- Configuration & Colors ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

AUTO_COMMIT=false

# --- Utility Functions ---
log_info()  { echo -e "${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "${YELLOW}!${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; exit 1; }
log_step()  { echo -e "\n${BLUE}➜${NC} ${BOLD}$1${NC}"; }

ask_confirm() {
  local prompt_text=$1
  echo -ne "${CYAN}?${NC} ${prompt_text} ${GRAY}(y/N)${NC} "
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}

# Run a command silently, but show output if it fails
run_check() {
    local label=$1
    local cmd=$2
    local temp_log
    temp_log=$(mktemp)

    echo -ne "${GRAY}${label}...${NC} "

    # Run command, capturing both stdout and stderr
    if eval "$cmd" > "$temp_log" 2>&1; then
        echo -e "${GREEN}OK${NC}"
        rm "$temp_log"
        return 0
    else
        echo -e "${RED}Failed${NC}"
        echo -e "\n${YELLOW}=== Error Log: ${label} ===${NC}"
        cat "$temp_log"
        echo -e "${YELLOW}=============================${NC}\n"
        rm "$temp_log"
        return 1
    fi
}

# --- Pre-flight Checks ---
check_dependencies() {
    command -v bun >/dev/null 2>&1 || log_error "Bun is not installed."
    command -v git >/dev/null 2>&1 || log_error "Git is not installed."
    
    [ -f "package.json" ] || log_error "package.json not found. Run from project root."

    if ! command -v ncu >/dev/null 2>&1; then
        log_warn "npm-check-updates (ncu) not found."
        if ask_confirm "Install ncu globally via Bun?"; then
            bun add -g npm-check-updates
        else
            log_error "ncu is required for this script."
        fi
    fi

    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warn "You have uncommitted changes."
        ask_confirm "Continue anyway?" || exit 0
    fi
}

# --- Main Logic ---
main() {
    if [[ "$1" == "-y" || "$1" == "--yes" ]]; then
        AUTO_COMMIT=true
    fi

    clear
    echo -e "${BLUE}=== Dependency Update Workflow ===${NC}\n"
    check_dependencies

    # 1. Check & Select Updates
    log_step "Checking for outdated packages..."
    if ncu --interactive --format group; then
        log_info "Package file updated."
    else
        log_info "No updates selected or available."
        exit 0
    fi

    # 2. Install
    log_step "Installing via Bun..."
    rm -f bun.lock
    bun install
    log_info "bun.lock updated."

    # 3. Validate
    log_step "Running Validation Checks..."
    
    # We use '|| exit 1' to stop immediately if a check fails
    run_check "Checking Types" "bun x tsc --noEmit" || exit 1
    run_check "Linting" "bun run lint" || exit 1

    # Spelling is non-fatal (warn only)
    if ! run_check "Spell Check" "bun run lint:spelling"; then
        log_warn "Spelling issues found (ignoring for build)..."
    fi

    run_check "Production Build" "bun run build" || exit 1

    # 4. Commit
    log_step "Review Changes"
    echo -e "${GRAY}Packages updated:${NC}"
    git diff package.json | grep -E "^\+.*\"" | sed 's/^+/  /'

    if [ "$AUTO_COMMIT" = true ] || ask_confirm "\nCommit these updates?"; then
        git add package.json bun.lock
        git commit -m "chore: update dependencies"
        log_info "Updates committed successfully."
    else
        log_warn "Changes left staged/unstaged."
    fi
}

main "$@"