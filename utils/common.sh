#!/bin/bash

# =============================================================================
# Common Utility Functions
# Shared functions used across all modules
# =============================================================================

set -euo pipefail

# =============================================================================
# System Validation Functions
# =============================================================================

check_requirements() {
    log_debug "Checking system requirements..."
    
    # Determine if root is required based on the operation
    local requires_root=true
    
    # Check command line arguments to see if this is a user-only operation
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --config|--list|--help)
                requires_root=false
                ;;
            envmgr|poetry|pyenv|pipenv)
                # User-specific environment managers can run as user
                requires_root=false
                ;;
        esac
    fi
    
    # Also check if ALLOW_NON_ROOT is explicitly set
    if [[ "${ALLOW_NON_ROOT:-false}" == "true" ]]; then
        requires_root=false
    fi
    
    # Check if running as root (required for system operations)
    if [[ $requires_root == "true" && $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges (use sudo)"
        log_info "For user-specific operations, try: ALLOW_NON_ROOT=true ./setup.sh <command>"
        exit 1
    fi
    
    if [[ $requires_root == "false" && $EUID -ne 0 ]]; then
        log_info "Running in user mode (non-root) - some operations may be limited"
    fi
    
    # Check if we're in a supported environment
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warn "This script is designed for Ubuntu. Current OS: $ID"
        log_warn "Proceeding anyway, but some operations may fail"
    fi
    
    # Check required directories exist
    for dir in "$MODULES_DIR" "$UTILS_DIR" "$CONFIG_DIR"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Required directory not found: $dir"
            exit 1
        fi
    done
    
    log_debug "System requirements check passed"
}

check_command() {
    local cmd="$1"
    local package="${2:-$cmd}"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_warn "Command '$cmd' not found. Package '$package' may need to be installed."
        return 1
    fi
    return 0
}

check_user_exists() {
    local username="$1"
    if id "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_group_exists() {
    local groupname="$1"
    if getent group "$groupname" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# File and Directory Operations
# =============================================================================

backup_file() {
    local file="$1"
    local backup_suffix="${2:-.backup.$(date +%Y%m%d_%H%M%S)}"
    
    if [[ -f "$file" ]]; then
        local backup_file="${file}${backup_suffix}"
        log_debug "Backing up $file to $backup_file"
        cp "$file" "$backup_file"
        echo "$backup_file"  # Return the backup filename
        return 0
    else
        log_debug "File $file does not exist, no backup needed"
        return 1
    fi
}

create_directory() {
    local dir="$1"
    local owner="${2:-}"
    local permissions="${3:-755}"
    
    if [[ ! -d "$dir" ]]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir"
        chmod "$permissions" "$dir"
        
        if [[ -n "$owner" ]]; then
            chown "$owner" "$dir"
        fi
    else
        log_debug "Directory already exists: $dir"
    fi
}

safe_append_to_file() {
    local file="$1"
    local content="$2"
    local marker="${3:-# Added by setup-utility}"
    
    # Check if content already exists
    if [[ -f "$file" ]] && grep -Fq "$content" "$file"; then
        log_debug "Content already exists in $file"
        return 0
    fi
    
    log_debug "Appending content to $file"
    echo "$marker" >> "$file"
    echo "$content" >> "$file"
    echo "" >> "$file"
}

# =============================================================================
# Package Management
# =============================================================================

update_package_cache() {
    log_info "Updating package cache..."
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: apt update"
        return 0
    fi
    
    apt update || {
        log_error "Failed to update package cache"
        return 1
    }
}

install_packages() {
    local packages_to_install=("$@")
    
    if [[ ${#packages_to_install[@]} -eq 0 ]]; then
        log_warn "No packages specified for installation"
        return 0
    fi
    
    log_info "Ensuring the following packages are installed: ${packages_to_install[*]}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install: ${packages_to_install[*]}"
        return 0
    fi
    
    # Let apt handle checking for existing packages and installing only what's new.
    # This is generally faster than checking each one with dpkg beforehand.
    DEBIAN_FRONTEND=noninteractive apt install -y "${packages_to_install[@]}" || {
        log_error "Failed to install one or more packages: ${packages_to_install[*]}"
        return 1
    }
}

# =============================================================================
# User and Permission Management
# =============================================================================

create_user_if_not_exists() {
    local username="$1"
    local uid="${2:-}"
    local gid="${3:-}"
    local home_dir="${4:-/home/$username}"
    local shell="${5:-/bin/bash}"
    
    if check_user_exists "$username"; then
        log_info "User '$username' already exists"
        return 0
    fi
    
    log_info "Creating user: $username"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create user: $username"
        return 0
    fi
    
    local useradd_args=(-m -s "$shell")
    
    if [[ -n "$uid" ]]; then
        useradd_args+=(-u "$uid")
    fi
    
    if [[ -n "$gid" ]]; then
        useradd_args+=(-g "$gid")
    fi
    
    useradd "${useradd_args[@]}" "$username" || {
        log_error "Failed to create user: $username"
        return 1
    }
    
    log_success "User '$username' created successfully"
}

create_group_if_not_exists() {
    local groupname="$1"
    local gid="${2:-}"
    
    if check_group_exists "$groupname"; then
        log_info "Group '$groupname' already exists"
        return 0
    fi
    
    log_info "Creating group: $groupname"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create group: $groupname"
        return 0
    fi
    
    local groupadd_args=()
    if [[ -n "$gid" ]]; then
        groupadd_args+=(-g "$gid")
    fi
    
    groupadd "${groupadd_args[@]}" "$groupname" || {
        log_error "Failed to create group: $groupname"
        return 1
    }
    
    log_success "Group '$groupname' created successfully"
}

add_user_to_group() {
    local username="$1"
    local groupname="$2"
    
    if groups "$username" | grep -q "\b$groupname\b"; then
        log_debug "User '$username' already in group '$groupname'"
        return 0
    fi
    
    log_info "Adding user '$username' to group '$groupname'"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would add user '$username' to group '$groupname'"
        return 0
    fi
    
    usermod -aG "$groupname" "$username" || {
        log_error "Failed to add user '$username' to group '$groupname'"
        return 1
    }
}

# =============================================================================
# Environment and Configuration
# =============================================================================

set_environment_variable() {
    local var_name="$1"
    local var_value="$2"
    local config_file="${3:-/etc/environment}"
    
    log_debug "Setting environment variable: $var_name=$var_value"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would set $var_name=$var_value in $config_file"
        return 0
    fi
    
    # Remove existing entry if it exists
    if [[ -f "$config_file" ]]; then
        sed -i "/^$var_name=/d" "$config_file"
    fi
    
    # Add new entry
    echo "$var_name=$var_value" >> "$config_file"
}

# =============================================================================
# Progress and Status
# =============================================================================

show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"
    local width=100
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    
    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="#"
    done
    for ((i=filled; i<width; i++)); do
        bar+="."
    done
    
    # Print progress bar with carriage return (overwrites previous line)
    printf "\r%s: [%3d%%] [%s]" "$message" "$percent" "$bar"
    
    # Add newline when complete
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "${FORCE_YES:-false}" == "true" ]]; then
        log_debug "Auto-confirming: $message"
        return 0
    fi
    
    local prompt="$message"
    if [[ "$default" == "y" ]]; then
        prompt+=" [Y/n]: "
    else
        prompt+=" [y/N]: "
    fi
    
    while true; do
        read -p "$prompt" response
        response=${response:-$default}
        
        case ${response,,} in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_username() {
    local username="$1"
    
    # Check length
    if [[ ${#username} -lt 1 || ${#username} -gt 32 ]]; then
        log_error "Username must be 1-32 characters long"
        return 1
    fi
    
    # Check valid characters (alphanumeric, underscore, hyphen)
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Username contains invalid characters"
        return 1
    fi
    
    # Check doesn't start with number or hyphen
    if [[ "$username" =~ ^[0-9-] ]]; then
        log_error "Username cannot start with a number or hyphen"
        return 1
    fi
    
    return 0
}

validate_email() {
    local email="$1"
    local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
    
    if [[ "$email" =~ $email_regex ]]; then
        return 0
    else
        log_error "Invalid email format: $email"
        return 1
    fi
}

# =============================================================================
# Cleanup Functions
# =============================================================================

cleanup_temp_files() {
    local temp_dir="${1:-/tmp/setup-utility-$$}"
    
    if [[ -d "$temp_dir" ]]; then
        log_debug "Cleaning up temporary directory: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Set up cleanup trap
setup_cleanup_trap() {
    trap 'cleanup_temp_files; log_info "Script interrupted, cleaning up..."' INT TERM EXIT
}

# =============================================================================
# User Management Functions
# =============================================================================

run_as_user() {
    local target_user="$1"
    local command="$2"
    
    if [[ -z "$target_user" || -z "$command" ]]; then
        log_error "Usage: run_as_user <username> <command>"
        return 1
    fi
    
    # Check if user exists
    if ! id "$target_user" >/dev/null 2>&1; then
        log_error "User '$target_user' does not exist"
        return 1
    fi
    
    log_info "Running command as user '$target_user': $command"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run as $target_user: $command"
        return 0
    fi
    
    # Use su to run command as the target user with proper environment
    if su - "$target_user" -c "$command"; then
        log_success "Command completed successfully as user '$target_user'"
        return 0
    else
        local exit_code=$?
        log_error "Command failed as user '$target_user' with exit code $exit_code"
        return $exit_code
    fi
}
