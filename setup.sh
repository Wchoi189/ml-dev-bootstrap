#!/bin/bash

# =============================================================================
# Development Environment Setup Utility
# Modular setup script for Ubuntu-based development environments
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
MODULES_DIR="$SCRIPT_DIR/modules"
UTILS_DIR="$SCRIPT_DIR/utils"

# Configuration
CONFIG_FILE="$CONFIG_DIR/defaults.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Default values (can be overridden by config file)
USERNAME=${USERNAME:-vscode}
USER_GROUP=${USER_GROUP:-vscode}
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}
DEFAULT_LOCALE=${DEFAULT_LOCALE:-en_US.UTF-8}
GIT_USER_NAME=${GIT_USER_NAME:-Developer}
GIT_USER_EMAIL=${GIT_USER_EMAIL:-vscode@example.com}
GIT_DEFAULT_BRANCH=${GIT_DEFAULT_BRANCH:-main}
LOG_LEVEL=${LOG_LEVEL:-INFO}

# Module execution order (important for dependencies)
MODULE_ORDER=("system" "locale" "ssh" "envmgr" "prompt" "git")

# Module descriptions using individual variables
MODULES_SYSTEM="System development tools and apt updates"
MODULES_LOCALE="Locale configuration - English/Korean"
MODULES_USER="User and group creation with permissions"
MODULES_SOURCES="APT sources configuration for regional mirrors"
MODULES_SSH="SSH key generation, client configuration, and agent setup"
MODULES_ENVMGR="Python environment managers (UV default - Conda, Micromamba, Pyenv, Poetry, Pipenv)"
MODULES_CONDA="Backward compatibility alias for conda module"
MODULES_PROMPT="Color shell prompt configuration"
MODULES_GIT="Git configuration setup"

# =============================================================================
# Utility Functions (must be defined before use)
# =============================================================================

# Function to get module description
get_module_description() {
    local module="$1"
    local var_name="MODULES_${module^^}"  # Convert to uppercase
    echo "${!var_name:-Unknown module}"
}

# Function to check if module is valid
is_valid_module() {
    local module="$1"
    for valid_module in "${MODULE_ORDER[@]}"; do
        if [[ "$module" == "$valid_module" ]]; then
            return 0
        fi
    done
    return 1
}

# Basic logging functions (simplified versions)
log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*"
}

log_debug() {
    [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]] && echo "[DEBUG] $*" >&2
}

log_header() {
    echo ""
    echo "=== $* ==="
    echo ""
}

log_separator() {
    echo "----------------------------------------"
}

# Basic utility functions
init_logging() {
    # Initialize logging system
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
}

check_requirements() {
    # Basic requirement checks
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    # Check if required directories exist
    for dir in "$CONFIG_DIR" "$MODULES_DIR" "$UTILS_DIR"; do
        if [[ ! -d "$dir" ]]; then
            log_warn "Directory not found: $dir"
        fi
    done
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

check_user_exists() {
    id "$1" >/dev/null 2>&1
}

confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    read -p "$prompt [y/N]: " response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

update_package_cache() {
    log_info "Updating package cache..."
    apt update >/dev/null 2>&1
}

# Execute permissions for the script and modules
ensure_script_permissions() {
    log_debug "Ensuring proper script permissions..."

    # Make setup.sh executable
    chmod +x "$0" 2>/dev/null || true

    # Make all module files executable
    if [[ -d "$MODULES_DIR" ]]; then
        find "$MODULES_DIR" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
        log_debug "Module files made executable"
    fi

    # Make utility files executable
    if [[ -d "$UTILS_DIR" ]]; then
        find "$UTILS_DIR" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
        log_debug "Utility files made executable"
    fi

    # Make test script executable
    if [[ -f "$SCRIPT_DIR/test_setup.sh" ]]; then
        chmod +x "$SCRIPT_DIR/test_setup.sh" 2>/dev/null || true
        log_debug "Test script made executable"
    fi
}

# =============================================================================
# Main Functions
# =============================================================================

# =============================================================================
# Maintenance Functions
# =============================================================================

update_environment() {
    log_header "Environment Update"

    log_info "Updating development environment components..."

    # Update system packages
    if confirm_action "Update system packages?" "y"; then
        update_package_cache
        DEBIAN_FRONTEND=noninteractive apt upgrade -y || log_warn "Some packages failed to upgrade"
    fi

    # Update conda
    if [[ -n "${DETECTED_CONDA_PATH:-}" ]] && confirm_action "Update conda?" "y"; then
        if [[ -f "$DETECTED_CONDA_PATH/etc/profile.d/conda.sh" ]]; then
            source "$DETECTED_CONDA_PATH/etc/profile.d/conda.sh"
            conda update -n base -c defaults conda -y || log_warn "Conda update failed"
            conda update -n base --all -y || log_warn "Conda package updates failed"
        fi
    fi

    # Clean up
    if confirm_action "Clean up package caches?" "y"; then
        apt autoremove -y >/dev/null 2>&1
        apt autoclean >/dev/null 2>&1

        if [[ -n "${DETECTED_CONDA_PATH:-}" ]]; then
            "$DETECTED_CONDA_PATH/bin/conda" clean --all -y >/dev/null 2>&1 || true
        fi
    fi

    log_success "Environment update completed"
}

backup_environment() {
    local backup_dir="/tmp/dev-env-backup-$(date +%Y%m%d_%H%M%S)"

    log_info "Creating environment backup in: $backup_dir"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create backup in: $backup_dir"
        return 0
    fi

    mkdir -p "$backup_dir"

    # Backup configuration files
    local config_files=(
        "/home/$USERNAME/.bashrc"
        "/home/$USERNAME/.bash_aliases"
        "/home/$USERNAME/.bash_prompt_functions"
        "/home/$USERNAME/.bash_prompt_config"
        "/home/$USERNAME/.gitconfig"
        "/home/$USERNAME/.gitignore_global"
        "/home/$USERNAME/.conda/condarc"
        "/etc/default/locale"
        "/etc/environment"
    )

    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            local dest_dir="$backup_dir$(dirname "$file")"
            mkdir -p "$dest_dir"
            cp "$file" "$dest_dir/" 2>/dev/null || log_debug "Could not backup: $file"
        fi
    done

    # Create backup manifest
    cat > "$backup_dir/manifest.txt" << EOF
Development Environment Backup
Created: $(date)
Setup Utility Version: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

User: $USERNAME
Group: $USER_GROUP
Home: /home/$USERNAME

Backed up files:
$(find "$backup_dir" -type f | sed "s|$backup_dir||" | sort)

System Information:
OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
Kernel: $(uname -r)
Git Version: $(git --version 2>/dev/null || echo "Not installed")
Conda Path: ${DETECTED_CONDA_PATH:-Not detected}

To restore:
1. Copy files back to their original locations
2. Set proper ownership: chown -R $USERNAME:$USER_GROUP /home/$USERNAME
3. Re-run setup modules if needed
EOF

    log_success "Environment backup created: $backup_dir"
    echo "Backup manifest: $backup_dir/manifest.txt"
    return 0
}

# =============================================================================
# Enhanced Main Function
# =============================================================================

enhanced_main() {
# Load utilities if they exist
if [[ -f "$UTILS_DIR/common.sh" ]]; then
    source "$UTILS_DIR/common.sh"
fi

if [[ -f "$UTILS_DIR/logger.sh" ]]; then
    source "$UTILS_DIR/logger.sh"
fi

# Load menu module
if [[ -f "$SCRIPT_DIR/lib/menu.sh" ]]; then
    source "$SCRIPT_DIR/lib/menu.sh"
fi

# Load args module
if [[ -f "$SCRIPT_DIR/lib/args.sh" ]]; then
    source "$SCRIPT_DIR/lib/args.sh"
fi

# Load diagnostics module
if [[ -f "$MODULES_DIR/diagnostics.sh" ]]; then
    source "$MODULES_DIR/diagnostics.sh"
fi

# Load orchestrator module
if [[ -f "$SCRIPT_DIR/lib/orchestrator.sh" ]]; then
    source "$SCRIPT_DIR/lib/orchestrator.sh"
fi

    # Ensure proper permissions first
    ensure_script_permissions

    # Initialize logging
    init_logging

    # Parse command line arguments using the args module
    parse_arguments "$@"

    # Validate parsed arguments
    validate_arguments

    # Execute based on options
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        backup_environment
    elif [[ "$RUN_UPDATE" == "true" ]]; then
        update_environment
    elif [[ "$RUN_DIAGNOSTICS" == "true" ]]; then
        run_full_diagnostics
    elif [[ "$SHOW_MENU_FLAG" == "true" ]]; then
        show_menu
    elif [[ "$RUN_ALL" == "true" ]]; then
        if [[ "${SHOW_PROGRESS:-false}" == "true" ]]; then
            run_all_modules_with_progress
        else
            execute_all_modules
        fi
    elif [[ ${#MODULES_TO_RUN[@]} -gt 0 ]]; then
        for module in "${MODULES_TO_RUN[@]}"; do
            execute_module "$module"
        done
    else
        log_info "No action specified. Use --help for usage information."
        show_usage
        exit 1
    fi
}

# =============================================================================
# Legacy Main Function (for backward compatibility)
# =============================================================================

main() {
    # Initialize logging
    init_logging

    # Parse command line arguments using legacy parser
    parse_legacy_arguments "$@"

    # Validate environment
    check_requirements

    # Execute based on options
    if [[ "$SHOW_MENU_FLAG" == "true" ]]; then
        show_menu
    elif [[ "$RUN_ALL" == "true" ]]; then
        execute_all_modules
    elif [[ ${#MODULES_TO_RUN[@]} -gt 0 ]]; then
        for module in "${MODULES_TO_RUN[@]}"; do
            execute_module "$module"
        done
    else
        log_info "No action specified. Use --help for usage information."
        show_usage
        exit 1
    fi
}

# =============================================================================
# Script Entry Point
# =============================================================================

# Run enhanced main function
enhanced_main "$@"