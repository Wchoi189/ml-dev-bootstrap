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

# Load utilities
source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/logger.sh"

# Configuration
CONFIG_FILE="$CONFIG_DIR/defaults.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Default values (can be overridden by config file)
USERNAME=${USERNAME:-wb2x}
USER_GROUP=${USER_GROUP:-dev}
LOG_LEVEL=${LOG_LEVEL:-INFO}

# Default configuration (add this section)
# USERNAME=${USERNAME:-wb2x}
# USER_GROUP=${USER_GROUP:-dev}
# USER_UID=${USER_UID:-1000}
# USER_GID=${USER_GID:-1000}
# DEFAULT_LOCALE=${DEFAULT_LOCALE:-en_US.UTF-8}
# GIT_USER_NAME=${GIT_USER_NAME:-Developer}
# GIT_USER_EMAIL=${GIT_USER_EMAIL:-dev@example.com}
# GIT_DEFAULT_BRANCH=${GIT_DEFAULT_BRANCH:-main}

# Available modules
# declare -A MODULES=(
#     ["system"]="System development tools and apt updates"
#     ["locale"]="Locale configuration (English/Korean)"
#     ["user"]="User and group creation with permissions"
#     ["conda"]="Conda environment updates"
#     ["prompt"]="Color shell prompt configuration"
#     ["git"]="Git configuration setup"
# )

# Module execution order (important for dependencies)
MODULE_ORDER=("system" "locale" "user" "conda" "prompt" "git")

# Add this near the top of setup.sh after the MODULE_ORDER definition
declare -A MODULES=(
    ["system"]="System development tools and apt updates"
    ["locale"]="Locale configuration (English/Korean)"
    ["user"]="User and group creation with permissions"
    ["conda"]="Conda environment updates"
    ["prompt"]="Color shell prompt configuration"
    ["git"]="Git configuration setup"
)
# =============================================================================
# Functions
# =============================================================================

show_usage() {
    cat << EOF
Development Environment Setup Utility

Usage: $0 [OPTIONS] [MODULES...]

OPTIONS:
    -h, --help          Show this help message
    -a, --all           Run all modules in order
    -m, --menu          Show interactive menu
    -l, --list          List available modules
    -c, --config        Show current configuration
    -d, --dry-run       Preview what would be executed
    -v, --verbose       Enable verbose logging

MODULES:
EOF
    for module in "${MODULE_ORDER[@]}"; do
        printf "    %-12s %s\n" "$module" "${MODULES[$module]}"
    done
    
    cat << EOF

EXAMPLES:
    $0 --all                    # Run all modules
    $0 --menu                   # Interactive menu
    $0 system locale user       # Run specific modules
    $0 --dry-run --all         # Preview all operations

EOF
}

show_config() {
    log_info "Current Configuration:"
    echo "  Username: $USERNAME"
    echo "  User Group: $USER_GROUP"
    echo "  Log Level: $LOG_LEVEL"
    echo "  Script Directory: $SCRIPT_DIR"
    echo "  Config File: $CONFIG_FILE"
}

list_modules() {
    log_info "Available Modules:"
    for module in "${MODULE_ORDER[@]}"; do
        printf "  %-12s %s\n" "$module" "${MODULES[$module]}"
    done
}

show_menu() {
    while true; do
        clear
        echo "=== Development Environment Setup Menu ==="
        echo
        echo "Available modules:"
        local i=1
        for module in "${MODULE_ORDER[@]}"; do
            printf "%d) %-12s %s\n" $i "$module" "${MODULES[$module]}"
            ((i++))
        done
        echo
        echo "a) Run all modules"
        echo "c) Show configuration"
        echo "q) Quit"
        echo
        read -p "Select option: " choice
        
        case $choice in
            [1-6])
                local module_index=$((choice - 1))
                local selected_module="${MODULE_ORDER[$module_index]}"
                execute_module "$selected_module"
                read -p "Press Enter to continue..."
                ;;
            a|A)
                execute_all_modules
                read -p "Press Enter to continue..."
                ;;
            c|C)
                show_config
                read -p "Press Enter to continue..."
                ;;
            q|Q)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_warn "Invalid option: $choice"
                sleep 1
                ;;
        esac
    done
}

execute_all_modules() {
    log_info "Executing all modules in order..."
    for module in "${MODULE_ORDER[@]}"; do
        execute_module "$module" || {
            log_error "Failed to execute module: $module"
            return 1
        }
    done
    log_success "All modules completed successfully!"
}

execute_module() {
    local module="$1"
    local module_file="$MODULES_DIR/${module}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module file not found: $module_file"
        return 1
    fi
    
    log_info "Executing module: $module"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $module_file"
        return 0
    fi
    
    # Source the module file
    if ! source "$module_file"; then
        log_error "Failed to source module file: $module_file"
        return 1
    fi
    
    # Check if the run function exists
    if ! declare -f "run_${module}" > /dev/null; then
        log_error "Function run_${module} not found in $module_file"
        return 1
    fi
    
    # Execute the module function directly
    log_debug "Starting run_${module} function..."
    
    if "run_${module}"; then
        log_success "Module $module completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Module $module failed with exit code $exit_code"
        return 1
    fi
}


detect_conda_installation() {
    log_info "Detecting conda installation..."
    
    # Check multiple possible locations
    local conda_paths=(
        "/opt/conda/bin/conda"
        "/usr/bin/conda"
        "/home/$DEV_USERNAME/miniconda3/bin/conda"
        "$CONDA_PATH/bin/conda"
    )
    
    for path in "${conda_paths[@]}"; do
        if [[ -x "$path" ]]; then
            DETECTED_CONDA_PATH=$(dirname "$(dirname "$path")")
            log_success "Found conda installation: $DETECTED_CONDA_PATH"
            return 0
        fi
    done
    
    log_error "No conda installation found"
    return 1
}

setup_fresh_conda() {
    log_info "Setting up fresh conda installation..."
    
    # Initialize conda if not already done
    if ! grep -q "conda initialize" ~/.bashrc; then
        log_info "Initializing conda..."
        "$DETECTED_CONDA_PATH/bin/conda" init bash
        source ~/.bashrc
    fi
    
    # Basic conda configuration
    "$DETECTED_CONDA_PATH/bin/conda" config --set auto_activate_base false
    "$DETECTED_CONDA_PATH/bin/conda" config --set channel_priority strict
    
    log_success "Fresh conda setup completed"
}
# =============================================================================
# Final Integration Functions
# =============================================================================

run_all_modules_with_progress() {
    log_header "Complete Development Environment Setup"
    
    local total_modules=${#MODULE_ORDER[@]}
    local completed_modules=0
    local failed_modules=()
    
    log_info "Starting complete setup with $total_modules modules..."
    log_separator
    
    for module in "${MODULE_ORDER[@]}"; do
        ((completed_modules++))
        
        log_header "Module $completed_modules/$total_modules: ${module^}"
        # Remove the problematic show_progress call
        log_info "Progress: $completed_modules/$total_modules modules"
        
        if execute_module "$module"; then
            log_success "Module '$module' completed successfully"
        else
            log_error "Module '$module' failed"
            failed_modules+=("$module")
            
            if ! confirm_action "Continue with remaining modules?" "y"; then
                log_warn "Setup cancelled by user"
                break
            fi
        fi
        
        log_separator
    done
    
    # Show final summary
    show_setup_summary $completed_modules $total_modules "${failed_modules[@]}"
}

show_setup_summary() {
    local completed="$1"
    local total="$2"
    shift 2
    local failed_modules=("$@")
    
    log_header "Setup Summary"
    
    echo "Modules processed: $completed/$total"
    
    if [[ ${#failed_modules[@]} -eq 0 ]]; then
        log_success "All modules completed successfully!"
        echo ""
        echo "✅ Your development environment is ready!"
        echo ""
        echo "Next steps:"
        echo "  1. Switch to development user: su - $USERNAME"
        echo "  2. Test the environment: source ~/.bashrc"
        echo "  3. Verify git configuration: git config --list"
        echo "  4. Test conda: conda --version"
        echo "  5. Check prompt: start a new shell session"
    else
        log_warn "Setup completed with ${#failed_modules[@]} failed modules"
        echo ""
        echo "Failed modules: ${failed_modules[*]}"
        echo ""
        echo "❌ Some components may not work correctly"
        echo ""
        echo "To fix issues:"
        echo "  1. Check logs for error details"
        echo "  2. Re-run failed modules individually"
        echo "  3. Use diagnostic functions: ./setup.sh --diagnose"
    fi
    
    echo ""
    echo "Environment Details:"
    echo "  • Username: $USERNAME"
    echo "  • User Group: $USER_GROUP"
    echo "  • Home Directory: /home/$USERNAME"
    echo "  • Git User: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    echo "  • Default Locale: ${DEFAULT_LOCALE:-en_US.UTF-8}"
    
    log_separator
}

# =============================================================================
# Diagnostic and Troubleshooting Functions
# =============================================================================

run_full_diagnostics() {
    log_header "Complete Environment Diagnostics"
    
    echo "Running comprehensive diagnostics..."
    echo ""
    
    # System diagnostics
    log_info "=== System Diagnostics ==="
    show_system_info
    echo ""
    
    # User diagnostics
    log_info "=== User Diagnostics ==="
    if declare -f diagnose_user_issues >/dev/null; then
        diagnose_user_issues
    else
        echo "User diagnostics not available (user module not loaded)"
    fi
    echo ""
    
    # Locale diagnostics
    log_info "=== Locale Diagnostics ==="
    if declare -f diagnose_locale_issues >/dev/null; then
        diagnose_locale_issues
    else
        echo "Locale diagnostics not available (locale module not loaded)"
    fi
    echo ""
    
    # Git diagnostics
    log_info "=== Git Diagnostics ==="
    if check_command "git"; then
        echo "Git version: $(git --version)"
        echo "Git configuration:"
        git config --global --list | head -10 | sed 's/^/  /'
        echo ""
        
        if check_user_exists "$USERNAME"; then
            echo "User git configuration:"
            sudo -u "$USERNAME" git config --global --list 2>/dev/null | head -5 | sed 's/^/  /' || echo "  No user git config found"
        fi
    else
        echo "Git not installed"
    fi
    echo ""
    
    # Conda diagnostics
    log_info "=== Conda Diagnostics ==="
    if [[ -n "${DETECTED_CONDA_PATH:-}" ]]; then
        echo "Conda path: $DETECTED_CONDA_PATH"
        echo "Conda version: $($DETECTED_CONDA_PATH/bin/conda --version 2>/dev/null || echo 'Not accessible')"
        echo "Conda environments:"
        $DETECTED_CONDA_PATH/bin/conda env list 2>/dev/null | head -5 | sed 's/^/  /' || echo "  Cannot list environments"
    else
        echo "Conda not detected"
    fi
    echo ""
    
    # Prompt diagnostics
    log_info "=== Prompt Diagnostics ==="
    if [[ -f "/home/$USERNAME/.bash_prompt_functions" ]]; then
        echo "✓ Prompt functions file exists"
        echo "✓ Prompt configuration: ${PROMPT_STYLE:-not set}"
    else
        echo "✗ Prompt functions file missing"
    fi
    
    if [[ -f "/home/$USERNAME/.bashrc" ]] && grep -q "bash_prompt_functions" "/home/$USERNAME/.bashrc"; then
        echo "✓ Prompt integrated in .bashrc"
    else
        echo "✗ Prompt not integrated in .bashrc"
    fi
    
    log_separator
}

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
        source "$DETECTED_CONDA_PATH/etc/profile.d/conda.sh"
        conda update -n base -c defaults conda -y || log_warn "Conda update failed"
        conda update -n base --all -y || log_warn "Conda package updates failed"
    fi
    
    # Clean up
    if confirm_action "Clean up package caches?" "y"; then
        apt autoremove -y >/dev/null 2>&1
        apt autoclean >/dev/null 2>&1
        
        if [[ -n "${DETECTED_CONDA_PATH:-}" ]]; then
            conda clean --all -y >/dev/null 2>&1
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
# Enhanced Main Function with New Options
# =============================================================================

# Update the main function to include new options
enhanced_main() {
    # Ensure proper permissions first
    ensure_script_permissions    
    # Initialize logging
    init_logging
    
    # Parse command line arguments (enhanced)
    local modules_to_run=()
    local show_menu_flag=false
    local run_all=false
    local run_diagnostics=false
    local run_update=false
    local create_backup=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            -m|--menu)
                show_menu_flag=true
                shift
                ;;
            -l|--list)
                list_modules
                exit 0
                ;;
            -c|--config)
                show_config
                exit 0
                ;;
            -d|--dry-run)
                export DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            -v|--verbose)
                export LOG_LEVEL=DEBUG
                shift
                ;;
            --diagnose)
                run_diagnostics=true
                shift
                ;;
            --update)
                run_update=true
                shift
                ;;
            --backup)
                create_backup=true
                shift
                ;;
        --skip-upgrade)
                export AUTO_UPGRADE=false
                log_info "Skipping system package upgrade."
                shift
                ;;
        --progress)
                export SHOW_PROGRESS=true
                shift
                ;;                
            --progress)
                export SHOW_PROGRESS=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Check if it's a valid module
                if [[ -n "${MODULES[$1]:-}" ]]; then
                    modules_to_run+=("$1")
                else
                    log_error "Unknown module: $1"
                    list_modules
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate environment
    check_requirements
    
    # Execute based on options
    if [[ "$create_backup" == "true" ]]; then
        backup_environment
    elif [[ "$run_update" == "true" ]]; then
        update_environment
    elif [[ "$run_diagnostics" == "true" ]]; then
        run_full_diagnostics
    elif [[ "$show_menu_flag" == "true" ]]; then
        show_menu
    elif [[ "$run_all" == "true" ]]; then
        if [[ "${SHOW_PROGRESS:-false}" == "true" ]]; then
            run_all_modules_with_progress
        else
            execute_all_modules
        fi
    elif [[ ${#modules_to_run[@]} -gt 0 ]]; then
        for module in "${modules_to_run[@]}"; do
            execute_module "$module"
        done
    else
        log_info "No action specified. Use --help for usage information."
        show_usage
        exit 1
    fi
}

# =============================================================================
# Enhanced Usage Function
# =============================================================================

enhanced_show_usage() {
    cat << EOF
Development Environment Setup Utility v2.0

Usage: $0 [OPTIONS] [MODULES...]

OPTIONS:
    -h, --help          Show this help message
    -a, --all           Run all modules in order
    -m, --menu          Show interactive menu
    -l, --list          List available modules
    -c, --config        Show current configuration
    -d, --dry-run       Preview what would be executed
    -v, --verbose       Enable verbose logging
    --diagnose          Run comprehensive diagnostics
    --update            Update environment components
    --backup            Create environment backup
    --progress          Show detailed progress for --all

MODULES:
EOF
    for module in "${MODULE_ORDER[@]}"; do
        printf "    %-12s %s\n" "$module" "${MODULES[$module]}"
    done
    
    cat << EOF

EXAMPLES:
    $0 --all --progress             # Run all modules with progress
    $0 --menu                       # Interactive menu
    $0 system locale user           # Run specific modules
    $0 --dry-run --all             # Preview all operations
    $0 --diagnose                   # Run diagnostics
    $0 --update                     # Update environment
    $0 --backup                     # Create backup

TROUBLESHOOTING:
    $0 --diagnose                   # Comprehensive diagnostics
    $0 user --dry-run              # Test user module
    $0 --verbose system            # Debug system module

For more information, see the documentation or run with --diagnose.

EOF
}      
# =============================================================================
# Main
# =============================================================================

main() {
    # Initialize logging
    init_logging
    
    # Parse command line arguments
    local modules_to_run=()
    local show_menu_flag=false
    local run_all=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            -m|--menu)
                show_menu_flag=true
                shift
                ;;
            -l|--list)
                list_modules
                exit 0
                ;;
            -c|--config)
                show_config
                exit 0
                ;;
            -d|--dry-run)
                export DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            -v|--verbose)
                export LOG_LEVEL=DEBUG
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Check if it's a valid module
                if [[ -n "${MODULES[$1]:-}" ]]; then
                    modules_to_run+=("$1")
                else
                    log_error "Unknown module: $1"
                    list_modules
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate environment
    check_requirements
    
    # Execute based on options
    if [[ "$show_menu_flag" == "true" ]]; then
        show_menu
    elif [[ "$run_all" == "true" ]]; then
        execute_all_modules
    elif [[ ${#modules_to_run[@]} -gt 0 ]]; then
        for module in "${modules_to_run[@]}"; do
            execute_module "$module"
        done
    else
        log_info "No action specified. Use --help for usage information."
        show_usage
        exit 1
    fi
}

# Run main function
# main "$@"
enhanced_main "$@"