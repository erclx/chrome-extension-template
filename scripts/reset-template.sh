#!/bin/bash
# ==============================================================================
# Script Name: reset-template.sh
# Location:    ./scripts/reset-template.sh
# Description: Resets the Bun+CRXJS template for a new project.
# Usage:       bun reset (via package.json)
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

# --- Utility Functions ---
log_info()  { echo -e "${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "${YELLOW}!${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; exit 1; }
log_step()  { echo -e "\n${BLUE}➜${NC} ${BOLD}$1${NC}"; }

ask() {
  local prompt_text=$1
  local var_name=$2
  local default_val=$3
  if [ -n "$default_val" ]; then
    echo -ne "${CYAN}?${NC} ${prompt_text} ${GRAY}(${default_val})${NC} "
  else
    echo -ne "${CYAN}?${NC} ${prompt_text} "
  fi
  read -r input
  [ -z "$input" ] && input="$default_val"
  export "$var_name"="$input"
}

# --- Pre-flight Checks ---
check_location() {
    # Ensure the script is run from the project root (where package.json lives)
    if [ ! -f "package.json" ]; then
        if [ -f "../package.json" ]; then
            log_warn "Running from inside 'scripts/' folder. Moving to root..."
            cd ..
        else
            log_error "Could not find package.json. Please run this script from the project root."
        fi
    fi
}

check_dependencies() {
    command -v bun >/dev/null 2>&1 || log_error "Bun is not installed."
    command -v git >/dev/null 2>&1 || log_error "Git is not installed."
}

# --- Main Logic ---
main() {
    clear
    echo -e "${BLUE}=== Chrome Extension Template Reset ===${NC}\n"
    
    check_location
    check_dependencies

    # 1. Collect Data
    current_dir_name=$(basename "$PWD")
    ask "Extension Name?" "PKG_NAME" "$current_dir_name"
    ask "Description?" "PKG_DESC" "A Chrome extension built with React & Vite."
    ask "Author?" "PKG_AUTHOR" "$(git config user.name 2>/dev/null || echo '')"

    # 2. Update Metadata
    log_step "Updating Project Metadata..."
    
    # Use Bun to safely edit JSON
    bun -e "
      const fs = require('fs');
      const pkgPath = 'package.json';
      if (fs.existsSync(pkgPath)) {
          const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
          
          pkg.name = process.env.PKG_NAME.toLowerCase().replace(/\s+/g, '-');
          pkg.description = process.env.PKG_DESC;
          pkg.author = process.env.PKG_AUTHOR;
          pkg.version = '0.0.1';
          
          // Remove the reset script from package.json
          if (pkg.scripts && pkg.scripts.reset) {
            delete pkg.scripts.reset;
          }
          
          fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
          console.log('${GREEN}✓${NC} package.json updated');
      }
    "

    # 3. Reset Documentation
    log_step "Resetting Documentation..."
    
    # Overwrite README
    cat > README.md <<EOF
# ${PKG_NAME}

${PKG_DESC}

## Development

1. Install dependencies:
   \`\`\`bash
   bun install
   \`\`\`

2. Start development server:
   \`\`\`bash
   bun dev
   \`\`\`

3. Load unpacked extension in Chrome from \`dist/\`.
EOF
    log_info "README.md initialized"

    # Create fresh Changelog
    cat > CHANGELOG.md <<EOF
# Changelog

All notable changes to "${PKG_NAME}" will be documented here.

## [Unreleased]

- Initial release
EOF
    log_info "CHANGELOG.md initialized"

    # 4. Re-initialize Git
    log_step "Resetting Git History..."
    rm -rf .git
    git init --quiet
    git add .
    git commit -m "chore: initial commit" --quiet
    log_info "New Git repository initialized."

    # 5. Clean & Install
    log_step "Refreshing Dependencies..."
    rm -rf node_modules bun.lock
    bun install
    log_info "Dependencies installed."

    # 6. Self Destruct
    log_step "Cleanup..."

    if [ -f "$0" ]; then
        rm "$0"
        log_info "Script deleted: $0"
    elif [ -f "scripts/reset-template.sh" ]; then
        rm "scripts/reset-template.sh"
        log_info "Script deleted: scripts/reset-template.sh"
    else
        log_warn "Could not self-destruct. Please remove scripts/reset-template.sh manually."
    fi

    echo -e "\n${GREEN}Success! Project '${PKG_NAME}' is ready.${NC}"
    echo -e "${GRAY}Run 'bun dev' to start coding.${NC}\n"
}

main "$@"