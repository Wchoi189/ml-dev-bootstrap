#!/bin/bash

# =============================================================================
# User and Permissions Management Module
# Creates development user, groups, and configures permissions
# =============================================================================

# User configuration (from config or defaults)
DEV_USERNAME="${USERNAME:-vscode-user}"
DEV_USER_UID="${USER_UID:-1000}"
DEV_USER_GID="${USER_GID:-1000}"
DEV_GROUP="${USER_GROUP:-vscode}"
DEV_HOME="/home/$DEV_USERNAME"

declare -a ESSENTIAL_GROUPS=(
    "sudo"        # Admin access
    "$DEV_GROUP" # Primary development group
)

declare -a OPTIONAL_GROUPS=(
    "www-data"    # Only for web development - UNCOMMENTED
    # "docker"      # Only if using Docker
    # "staff"       # Legacy group (rarely needed)
)
# Additional groups for development
# declare -a DEV_GROUPS=(
#     "sudo"
#     "docker"
#     "www-data"
#     "staff"
# )

# Directories to create in user home
declare -a USER_DIRECTORIES=(
    "bin"
    "tmp"
    "logs"
    ".config"
    ".local/bin"
    ".local/share"
)

# Development tool directories (optional)
declare -a DEV_DIRECTORIES=(
    "workspace"
    "scripts"
    "tools"
)

# =============================================================================
# Main User Setup Function
# =============================================================================

run_user() {
    log_header "User and Permissions Setup"

    local total_steps=7
    local current_step=0

    # Step 1: Validate user configuration

    # Enforce umask for group-writable files
    umask 002

    # Ensure the dev group exists
    if ! getent group "$DEV_GROUP" > /dev/null; then
        log_info "Group $DEV_GROUP does not exist. Creating..."
        groupadd "$DEV_GROUP"
    fi

    # Function to set setgid and group ownership recursively
    ensure_dev_group_permissions() {
        local target_dir="$1"
        chgrp -R "$DEV_GROUP" "$target_dir"
        chmod -R g+rw "$target_dir"
        find "$target_dir" -type d -exec chmod g+s {} +
    }

    # After creating user directories, enforce group and setgid
    for dir in "${USER_DIRECTORIES[@]}"; do
        mkdir -p "$DEV_HOME/$dir"
        chgrp "$DEV_GROUP" "$DEV_HOME/$dir"
        chmod 2775 "$DEV_HOME/$dir"  # setgid for directories
    done
    for dir in "${DEV_DIRECTORIES[@]}"; do
        mkdir -p "$DEV_HOME/$dir"
        chgrp "$DEV_GROUP" "$DEV_HOME/$dir"
        chmod 2775 "$DEV_HOME/$dir"
    done
    # Optionally, enforce recursively for all home
    # ensure_dev_group_permissions "$DEV_HOME"
    ((current_step++))
    log_step $current_step $total_steps "Validating user configuration"
    validate_user_config || {
        log_error "User configuration validation failed"
        return 1
    }

    # Step 2: Create development group
    ((current_step++))
    log_step $current_step $total_steps "Creating development group"
    create_development_group || {
        log_error "Failed to create development group"
        return 1
    }

    # Step 3: Create development user
    ((current_step++))
    log_step $current_step $total_steps "Creating development user"
    create_development_user || {
        log_error "Failed to create development user"
        return 1
    }

    # Step 4: Configure user groups
    ((current_step++))
    log_step $current_step $total_steps "Configuring user groups"
    configure_user_groups || {
        log_error "Failed to configure user groups"
        return 1
    }

    # Step 5: Set up user directories
    ((current_step++))
    log_step $current_step $total_steps "Setting up user directories"
    setup_user_directories || {
        log_error "Failed to set up user directories"
        return 1
    }

    # Step 6: Configure development permissions
    ((current_step++))
    log_step $current_step $total_steps "Configuring development permissions"
    configure_development_permissions || {
        log_error "Failed to configure development permissions"
        return 1
    }

    # Step 7: Set up user environment
    ((current_step++))
    log_step $current_step $total_steps "Setting up user environment"
    setup_user_environment || {
        log_error "Failed to set up user environment"
        return 1
    }

    log_success "User and permissions setup completed successfully!"
    show_user_info
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_user_config() {
    log_info "Validating user configuration..."

    # Validate username
    if ! validate_username "$DEV_USERNAME"; then
        log_error "Invalid username: $DEV_USERNAME"
        return 1
    fi

    # Validate UID/GID ranges
    if [[ $DEV_USER_UID -lt 1000 || $DEV_USER_UID -gt 65533 ]]; then
        log_error "UID $DEV_USER_UID is outside recommended range (1000-65533)"
        return 1
    fi

    if [[ $DEV_USER_GID -lt 1000 || $DEV_USER_GID -gt 65533 ]]; then
        log_error "GID $DEV_USER_GID is outside recommended range (1000-65533)"
        return 1
    fi

    # Check for UID/GID conflicts
    if getent passwd "$DEV_USER_UID" >/dev/null 2>&1; then
        local existing_user=$(getent passwd "$DEV_USER_UID" | cut -d: -f1)
        if [[ "$existing_user" != "$DEV_USERNAME" ]]; then
            log_error "UID $DEV_USER_UID is already used by user: $existing_user"
            return 1
        fi
    fi

    if getent group "$DEV_USER_GID" >/dev/null 2>&1; then
        local existing_group=$(getent group "$DEV_USER_GID" | cut -d: -f1)
        if [[ "$existing_group" != "$DEV_GROUP" ]]; then
            log_error "GID $DEV_USER_GID is already used by group: $existing_group"
            return 1
        fi
    fi

    log_success "User configuration validation passed"
    return 0
}

# =============================================================================
# Group Management Functions
# =============================================================================
# Add this function (around line 169):

create_development_group() {
    log_info "Creating development group: $DEV_GROUP"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create group: $DEV_GROUP"
        return 0
    fi

    if check_group_exists "$DEV_GROUP"; then
        log_info "Development group '$DEV_GROUP' already exists"
        return 0
    fi

    # Create the group
    if groupadd -g "$DEV_USER_GID" "$DEV_GROUP" 2>/dev/null; then
        log_success "Group '$DEV_GROUP' created successfully"
    else
        log_error "Failed to create group: $DEV_GROUP"
        return 1
    fi

    log_success "Development group ready: $DEV_GROUP"
    return 0
}


ensure_system_groups() {
    log_debug "Ensuring required system groups exist..."

    # Only create groups, don't add users to them
    local system_groups=("sudo")  # Remove "staff" from here

    for group in "${system_groups[@]}"; do
        if ! check_group_exists "$group"; then
            log_info "Creating system group: $group"
            if [[ "${DRY_RUN:-false}" != "true" ]]; then
                groupadd "$group" 2>/dev/null || {
                    log_debug "Group $group may already exist"
                }
            fi
        fi
    done
}
# =============================================================================
# User Management Functions
# =============================================================================

create_development_user() {
    log_info "Creating development user: $DEV_USERNAME"

    if check_user_exists "$DEV_USERNAME"; then
        local existing_uid=$(id -u "$DEV_USERNAME" 2>/dev/null)
        local existing_gid=$(id -g "$DEV_USERNAME" 2>/dev/null)

        if [[ "$existing_uid" == "$DEV_USER_UID" && "$existing_gid" == "$DEV_USER_GID" ]]; then
            log_info "Development user '$DEV_USERNAME' already exists with correct UID/GID"
            return 0
        else
            log_warn "User '$DEV_USERNAME' exists with different UID/GID"
            log_warn "Existing: UID=$existing_uid, GID=$existing_gid"
            log_warn "Expected: UID=$DEV_USER_UID, GID=$DEV_USER_GID"

            if confirm_action "Continue with existing user?" "y"; then
                log_info "Using existing user configuration"
                return 0
            else
                log_error "User creation cancelled"
                return 1
            fi
        fi
    fi

    # Create the user
    create_user_if_not_exists "$DEV_USERNAME" "$DEV_USER_UID" "$DEV_USER_GID" "$DEV_HOME" "/bin/bash" || {
        log_error "Failed to create development user"
        return 1
    }

    # Set user password (optional)
    configure_user_password || {
        log_warn "Failed to configure user password"
    }

    log_success "Development user created: $DEV_USERNAME"
    return 0
}

configure_user_password() {
    if [[ "${SET_USER_PASSWORD:-false}" == "true" ]]; then
        log_info "Configuring user password..."

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] Would configure user password"
            return 0
        fi

        if [[ -n "${USER_PASSWORD:-}" ]]; then
            # Set password from environment variable
            echo "$DEV_USERNAME:$USER_PASSWORD" | chpasswd
            log_success "User password set from environment"
        else
            # Generate random password
            local random_password=$(openssl rand -base64 12 2>/dev/null || date +%s | sha256sum | base64 | head -c 12)
            echo "$DEV_USERNAME:$random_password" | chpasswd
            log_success "Random password generated for user"
            log_info "Password: $random_password"
            log_warn "Please save this password securely!"
        fi
    else
        log_debug "Skipping password configuration (SET_USER_PASSWORD=false)"
    fi

    return 0
}

# =============================================================================
# Group Assignment Functions
# =============================================================================

# Add this as the ONLY configure_user_groups function:

configure_user_groups() {
    log_info "Configuring user group memberships..."

    # Ensure system groups exist first
    ensure_system_groups

    # Only add to essential groups
    log_info "Adding user to essential groups: ${ESSENTIAL_GROUPS[*]}"

    for group in "${ESSENTIAL_GROUPS[@]}"; do
        # Skip the primary group (already set during user creation)
        if [[ "$group" == "$DEV_GROUP" ]]; then
            log_debug "Skipping primary group: $group"
            continue
        fi

        # Check if group exists
        if ! check_group_exists "$group"; then
            log_warn "Group '$group' does not exist, skipping"
            continue
        fi

        # Add user to group
        log_info "Adding user '$DEV_USERNAME' to group '$group'"
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] Would add user to group: $group"
        else
            usermod -a -G "$group" "$DEV_USERNAME" || {
                log_error "Failed to add user to group: $group"
                return 1
            }
        fi
    done

    # Verify no unexpected groups were added
    verify_user_groups

    log_success "User group configuration completed"
}

# Add this new function for non-interactive optional groups:
configure_optional_groups_auto() {
    for group in "${OPTIONAL_GROUPS[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            log_info "Auto-adding user '$DEV_USERNAME' to optional group '$group'"
            usermod -a -G "$group" "$DEV_USERNAME" || {
                log_warn "Failed to add user to optional group: $group"
            }
        else
            log_debug "Optional group '$group' does not exist, skipping"
        fi
    done
}

verify_user_groups() {
    log_debug "Verifying user group memberships..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would verify user groups"
        return 0
    fi

    local user_groups=$(groups "$DEV_USERNAME" 2>/dev/null | cut -d: -f2)

    log_debug "User '$DEV_USERNAME' is member of: $user_groups"

    # Check critical groups
    local critical_groups=("$DEV_GROUP" "sudo")
    local missing_groups=()

    for group in "${critical_groups[@]}"; do
        if ! echo "$user_groups" | grep -q "\b$group\b"; then
            missing_groups+=("$group")
        fi
    done

    if [[ ${#missing_groups[@]} -gt 0 ]]; then
        log_warn "User missing from critical groups: ${missing_groups[*]}"
        return 1
    fi

    log_debug "User group verification passed"
    return 0
}

# =============================================================================
# Directory Setup Functions
# =============================================================================

setup_user_directories() {
    log_info "Setting up user directories..."

    # Create user home directory if it doesn't exist
    if [[ ! -d "$DEV_HOME" ]]; then
        log_info "Creating user home directory: $DEV_HOME"
        create_directory "$DEV_HOME" "$DEV_USERNAME:$DEV_GROUP" "755"
    fi

    # Create standard user directories
    create_user_standard_directories || {
        log_error "Failed to create standard user directories"
        return 1
    }

    # Create development directories (optional)
    if [[ "${CREATE_DEV_DIRS:-true}" == "true" ]]; then
        create_development_directories || {
            log_warn "Failed to create some development directories"
        }
    fi

    # Set proper ownership and permissions
    fix_directory_ownership || {
        log_error "Failed to fix directory ownership"
        return 1
    }

    log_success "User directories setup completed"
    return 0
}

create_user_standard_directories() {
    log_debug "Creating standard user directories..."

    for dir in "${USER_DIRECTORIES[@]}"; do
        local full_path="$DEV_HOME/$dir"
        log_debug "Creating directory: $full_path"

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] Would create: $full_path"
            continue
        fi

        create_directory "$full_path" "$DEV_USERNAME:$DEV_GROUP" "755"
    done

    return 0
}

create_development_directories() {
    log_debug "Creating development directories..."

    for dir in "${DEV_DIRECTORIES[@]}"; do
        local full_path="$DEV_HOME/$dir"
        log_debug "Creating development directory: $full_path"

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] Would create: $full_path"
            continue
        fi

        create_directory "$full_path" "$DEV_USERNAME:$DEV_GROUP" "755"
    done

    return 0
}

fix_directory_ownership() {
    log_debug "Fixing directory ownership and permissions..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would fix ownership of $DEV_HOME"
        return 0
    fi

    # Ensure user owns their home directory
    chown -R "$DEV_USERNAME:$DEV_GROUP" "$DEV_HOME" || {
        log_error "Failed to set ownership of user home directory"
        return 1
    }

    # Set proper permissions for home directory
    chmod 755 "$DEV_HOME"

    # Set restrictive permissions for sensitive directories
    local sensitive_dirs=(".ssh" ".gnupg" ".config")
    for dir in "${sensitive_dirs[@]}"; do
        local full_path="$DEV_HOME/$dir"
        if [[ -d "$full_path" ]]; then
            chmod 700 "$full_path"
            log_debug "Set restrictive permissions for: $full_path"
        fi
    done

    return 0
}

# =============================================================================
# Development Permissions Functions
# =============================================================================
# Replace the entire configure_development_permissions function:

configure_development_permissions() {
    log_info "Configuring development environment permissions..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure development permissions"
        return 0
    fi

    # Only do essential permission configuration
    log_debug "Setting basic development permissions..."

    # Ensure user can write to their own home directory
    if [[ -d "$DEV_HOME" ]]; then
        chown "$DEV_USERNAME:$DEV_GROUP" "$DEV_HOME"
        chmod 755 "$DEV_HOME"
        log_debug "Home directory permissions set"
    fi

    # Create user's local bin directory if it doesn't exist
    local local_bin="$DEV_HOME/.local/bin"
    if [[ ! -d "$local_bin" ]]; then
        mkdir -p "$local_bin"
        chown "$DEV_USERNAME:$DEV_GROUP" "$local_bin"
        chmod 755 "$local_bin"
        log_debug "Created user local bin directory"
    fi

    # Configure setup directory permissions for continued access
    configure_setup_directory_permissions

    log_success "Development permissions configured"
    return 0
}

configure_setup_directory_permissions() {
    log_info "Configuring setup directory permissions for continued access..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure setup directory permissions"
        return 0
    fi

    # Get the setup directory path (where this script is running from)
    local setup_dir
    if [[ -n "${SCRIPT_DIR:-}" ]]; then
        setup_dir="$SCRIPT_DIR"
    else
        # Fallback: try to determine from current working directory or script location
        setup_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi

    if [[ ! -d "$setup_dir" ]]; then
        log_warn "Setup directory not found: $setup_dir"
        return 1
    fi

    log_debug "Configuring permissions for setup directory: $setup_dir"

    # Check if we're in /opt (preferred location)
    if [[ "$setup_dir" == /opt/ml-dev-bootstrap ]]; then
        log_debug "Setup directory is already in /opt - using optimal permissions"
        ensure_opt_permissions "$setup_dir"
    else
        log_debug "Setup directory not in /opt - creating proper setup"
        create_opt_setup "$setup_dir"
    fi

    # Create user-friendly symlinks
    create_user_symlinks

    log_success "Setup directory permissions configured for group access"
    log_info "User '$DEV_USERNAME' can now continue running setup scripts"
    log_info "Access via: ~/setup or /opt/ml-dev-bootstrap"
    return 0
}

ensure_opt_permissions() {
    local setup_dir="$1"

    log_debug "Ensuring optimal permissions for /opt setup directory"

    # Set proper ownership and permissions for /opt location
    chown -R root:"$DEV_GROUP" "$setup_dir" 2>/dev/null || {
        log_warn "Failed to set ownership on /opt setup directory"
        return 1
    }

    # Set directory permissions (775 with setgid)
    find "$setup_dir" -type d -exec chmod 2775 {} \; 2>/dev/null || {
        log_warn "Failed to set directory permissions"
    }

    # Set file permissions (664 for regular files, 774 for scripts)
    find "$setup_dir" -type f -not -name "*.sh" -exec chmod 664 {} \; 2>/dev/null || true
    find "$setup_dir" -name "*.sh" -type f -exec chmod 774 {} \; 2>/dev/null || {
        log_warn "Failed to set script permissions"
    }

    log_debug "Optimal permissions set for /opt setup directory"
}

create_opt_setup() {
    local current_dir="$1"
    local opt_dir="/opt/ml-dev-bootstrap"

    log_info "Moving setup files to /opt for better accessibility"

    # Copy to /opt if not already there
    if [[ "$current_dir" != "$opt_dir" ]]; then
        if [[ ! -d "$opt_dir" ]]; then
            cp -r "$current_dir" "$opt_dir" 2>/dev/null || {
                log_error "Failed to copy setup files to /opt"
                return 1
            }
        fi

        # Set permissions on /opt copy
        ensure_opt_permissions "$opt_dir"

        # Replace current directory with symlink
        if [[ -d "$current_dir" ]]; then
            rm -rf "$current_dir" 2>/dev/null || true
            ln -s "$opt_dir" "$current_dir" 2>/dev/null || {
                log_warn "Failed to create symlink from $current_dir to $opt_dir"
            }
        fi
    fi
}

create_user_symlinks() {
    local opt_dir="/opt/ml-dev-bootstrap"
    local user_home="/home/$DEV_USERNAME"

    log_debug "Creating user-friendly symlinks"

    # Create symlink in user's home directory
    if [[ -d "$user_home" ]]; then
        local user_symlink="$user_home/setup"
        if [[ ! -L "$user_symlink" ]]; then
            ln -s "$opt_dir" "$user_symlink" 2>/dev/null || {
                log_debug "Failed to create user symlink: $user_symlink"
            }
        fi
    fi

    # Ensure /opt symlink exists for backward compatibility
    local opt_symlink="/opt/setup"
    if [[ ! -L "$opt_symlink" ]]; then
        ln -s "$opt_dir" "$opt_symlink" 2>/dev/null || true
    fi
}

create_accessible_symlink() {
    local setup_dir="$1"
    local symlink_target="/opt/ml-dev-bootstrap"

    log_info "Creating accessible symlink at $symlink_target"

    # Create symlink in /opt (which is accessible to all users)
    if [[ -d "/opt" ]]; then
        ln -sf "$setup_dir" "$symlink_target" 2>/dev/null || {
            log_warn "Failed to create symlink in /opt"
            return 1
        }

        # Set permissions on the symlink
        chmod 755 "$symlink_target" 2>/dev/null || true

        log_success "Created symlink: $symlink_target -> $setup_dir"
        log_info "Users can now access setup files via: $symlink_target"
        return 0
    else
        log_warn "/opt directory not found, cannot create accessible symlink"
        return 1
    fi
}

configure_conda_permissions() {
    local conda_path="${CONDA_PATH:-/opt/conda}"

    if [[ ! -d "$conda_path" ]]; then
        log_debug "Conda directory not found: $conda_path"
        return 1
    fi

    log_debug "Configuring conda permissions for development group..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure conda permissions"
        return 0
    fi

    # Make conda accessible to development group
    chgrp -R "$DEV_GROUP" "$conda_path" 2>/dev/null || {
        log_warn "Failed to change conda group ownership"
        return 1
    }

    # Set group read/execute permissions
    find "$conda_path" -type d -exec chmod g+rx {} \; 2>/dev/null || {
        log_warn "Failed to set conda directory permissions"
    }

    find "$conda_path" -type f -executable -exec chmod g+rx {} \; 2>/dev/null || {
        log_warn "Failed to set conda executable permissions"
    }

    log_debug "Conda permissions configured"
    return 0
}

configure_system_dev_permissions() {
    log_debug "Configuring system development directory permissions..."

    local dev_dirs=("/usr/local" "/opt")

    for dir in "${dev_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            configure_dev_directory_permissions "$dir"
        fi
    done

    return 0
}

configure_dev_directory_permissions() {
    local dir="$1"

    log_debug "Configuring permissions for: $dir"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure permissions for: $dir"
        return 0
    fi

    # Create development subdirectories if they don't exist
    local dev_subdirs=("bin" "lib" "include" "share")
    for subdir in "${dev_subdirs[@]}"; do
        local full_path="$dir/$subdir"
        if [[ ! -d "$full_path" ]]; then
            mkdir -p "$full_path" 2>/dev/null || continue
        fi

        # Set group ownership to development group
        chgrp "$DEV_GROUP" "$full_path" 2>/dev/null || continue

        # Set group write permissions
        chmod g+w "$full_path" 2>/dev/null || continue
    done

    return 0
}

configure_docker_permissions() {
    if ! check_group_exists "docker"; then
        log_debug "Docker group does not exist"
        return 1
    fi

    log_debug "Configuring Docker permissions..."

    # User should already be added to docker group in configure_user_groups
    # Just verify the docker socket permissions
    local docker_socket="/var/run/docker.sock"

    if [[ -S "$docker_socket" ]]; then
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            chgrp docker "$docker_socket" 2>/dev/null || {
                log_debug "Could not change docker socket group"
            }
        fi
        log_debug "Docker permissions configured"
    else
        log_debug "Docker socket not found"
    fi

    return 0
}

configure_web_dev_permissions() {
    if ! check_group_exists "www-data"; then
        log_debug "www-data group does not exist"
        return 1
    fi

    log_debug "Configuring web development permissions..."

    local web_dirs=("/var/www" "/var/log/nginx" "/var/log/apache2")

    for dir in "${web_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ "${DRY_RUN:-false}" != "true" ]]; then
                # Add development group read access to web directories
                chmod g+r "$dir" 2>/dev/null || continue

                # For www directory, add write access for development
                if [[ "$dir" == "/var/www" ]]; then
                    chmod g+w "$dir" 2>/dev/null || continue
                fi
            fi
            log_debug "Configured permissions for: $dir"
        fi
    done

    return 0
}

# =============================================================================
# User Environment Setup Functions
# =============================================================================

setup_user_environment() {
    log_info "Setting up user environment..."

    # Create basic shell configuration
    create_user_bashrc || {
        log_error "Failed to create user .bashrc"
        return 1
    }

    # Create user profile
    create_user_profile || {
        log_warn "Failed to create user profile"
    }

    # Set up SSH directory (if needed)
    setup_ssh_directory || {
        log_debug "SSH directory setup skipped"
    }

    # Create basic development configuration
    create_dev_configuration || {
        log_warn "Failed to create development configuration"
    }

    log_success "User environment setup completed"
    return 0
}

create_user_bashrc() {
    local bashrc_file="$DEV_HOME/.bashrc"

    log_debug "Creating user .bashrc: $bashrc_file"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create user .bashrc"
        return 0
    fi

    # Backup existing .bashrc if it exists
    if [[ -f "$bashrc_file" ]]; then
        backup_file "$bashrc_file"
    fi

    # Create new .bashrc
    cat > "$bashrc_file" << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History configuration
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Set variable identifying the chroot you work in
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Common aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Development aliases
alias python='python3'
alias pip='pip3'

# Add local bin to PATH
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Conda initialization (if conda exists)
if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    . "/opt/conda/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
fi

# Load additional configurations
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.bash_local ]; then
    . ~/.bash_local
fi

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Development environment variables
export EDITOR=vim
export PAGER=less
export BROWSER=lynx

# Locale settings (will be configured by locale module)
export LANG=en_US.UTF-8
export LANGUAGE=en_US:ko_KR
export LC_ALL=en_US.UTF-8
EOF

    # Set ownership and permissions
    chown "$DEV_USERNAME:$DEV_GROUP" "$bashrc_file"
    chmod 644 "$bashrc_file"

    log_debug "User .bashrc created successfully"
    return 0
}

create_user_profile() {
    local profile_file="$DEV_HOME/.profile"

    log_debug "Creating user .profile: $profile_file"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create user .profile"
        return 0
    fi

    # Create .profile if it doesn't exist
    if [[ ! -f "$profile_file" ]]; then
        cat > "$profile_file" << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.

# Set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Source .bashrc if running bash
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
EOF

        chown "$DEV_USERNAME:$DEV_GROUP" "$profile_file"
        chmod 644 "$profile_file"
        log_debug "User .profile created"
    else
        log_debug "User .profile already exists"
    fi

    return 0
}

setup_ssh_directory() {
    if [[ "${SETUP_SSH:-false}" != "true" ]]; then
        return 1
    fi

    local ssh_dir="$DEV_HOME/.ssh"

    log_debug "Setting up SSH directory: $ssh_dir"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would setup SSH directory"
        return 0
    fi

    # Create .ssh directory
    create_directory "$ssh_dir" "$DEV_USERNAME:$DEV_GROUP" "700"

    # Create basic SSH config
    local ssh_config="$ssh_dir/config"
    if [[ ! -f "$ssh_config" ]]; then
        cat > "$ssh_config" << 'EOF'
# SSH client configuration
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    HashKnownHosts yes
    VisualHostKey yes
EOF
        chown "$DEV_USERNAME:$DEV_GROUP" "$ssh_config"
        chmod 600 "$ssh_config"
    fi

    # Create authorized_keys file
    local auth_keys="$ssh_dir/authorized_keys"
    if [[ ! -f "$auth_keys" ]]; then
        touch "$auth_keys"
        chown "$DEV_USERNAME:$DEV_GROUP" "$auth_keys"
        chmod 600 "$auth_keys"
    fi

    log_debug "SSH directory setup completed"
    return 0
}

create_dev_configuration() {
    log_debug "Creating development configuration files..."

    # Create .gitconfig (basic template - will be configured by git module)
    create_basic_gitconfig

    # Create .vimrc
    create_basic_vimrc

    # Create development aliases
    create_bash_aliases

    return 0
}

create_basic_gitconfig() {
    local gitconfig="$DEV_HOME/.gitconfig"

    if [[ -f "$gitconfig" ]]; then
        log_debug "Git config already exists, skipping"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create basic .gitconfig"
        return 0
    fi

    cat > "$gitconfig" << 'EOF'
[user]
    # Will be configured by git module
    name = Developer
    email = dev@example.com

[core]
    editor = vim
    autocrlf = input
    safecrlf = true

[init]
    defaultBranch = main

[color]
    ui = auto
EOF

    chown "$DEV_USERNAME:$DEV_GROUP" "$gitconfig"
    chmod 644 "$gitconfig"

    return 0
}

create_basic_vimrc() {
    local vimrc="$DEV_HOME/.vimrc"

    if [[ -f "$vimrc" ]]; then
        log_debug "Vim config already exists, skipping"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create basic .vimrc"
        return 0
    fi

    cat > "$vimrc" << 'EOF'
" Basic vim configuration
set nocompatible
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
set ruler
set laststatus=2
set encoding=utf-8
set fileencoding=utf-8

" Enable syntax highlighting
syntax on

" Enable file type detection
filetype on
filetype plugin on
filetype indent on

" Color scheme
colorscheme default

" Key mappings
nnoremap <C-n> :set number!<CR>
nnoremap <C-h> :set hlsearch!<CR>

" Auto-save when losing focus
au FocusLost * :wa
EOF

    chown "$DEV_USERNAME:$DEV_GROUP" "$vimrc"
    chmod 644 "$vimrc"

    return 0
}

create_bash_aliases() {
    local aliases_file="$DEV_HOME/.bash_aliases"

    if [[ -f "$aliases_file" ]]; then
        log_debug "Bash aliases already exist, skipping"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create .bash_aliases"
        return 0
    fi

    cat > "$aliases_file" << 'EOF'
# Development aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# Python aliases
alias python='python3'
alias pip='pip3'
alias venv='python3 -m venv'

# Docker aliases (if docker is available)
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dc='docker-compose'

# System aliases
alias h='history'
alias j='jobs -l'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowtime=now
alias nowdate='date +"%d-%m-%Y"'

# Network aliases
alias ports='netstat -tulanp'
alias wget='wget -c'

# Development shortcuts
alias serve='python3 -m http.server'
alias myip='curl -s ifconfig.me'
alias weather='curl -s wttr.in'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Conda aliases (if conda is available)
alias ca='conda activate'
alias cda='conda deactivate'
alias cl='conda list'
alias ce='conda env list'
EOF

    chown "$DEV_USERNAME:$DEV_GROUP" "$aliases_file"
    chmod 644 "$aliases_file"

    return 0
}

# =============================================================================
# Information Display Functions
# =============================================================================

show_user_info() {
    log_header "User Configuration Summary"

    echo "Development User: $DEV_USERNAME"
    echo "User ID: $DEV_USER_UID"
    echo "Primary Group: $DEV_GROUP (GID: $DEV_USER_GID)"
    echo "Home Directory: $DEV_HOME"
    echo ""

    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        echo "User Groups:"
        if check_user_exists "$DEV_USERNAME"; then
            groups "$DEV_USERNAME" | cut -d: -f2 | tr ' ' '\n' | sed 's/^/  /' | sort
        else
            echo "  User not found"
        fi

        echo ""
        echo "Home Directory Contents:"
        if [[ -d "$DEV_HOME" ]]; then
            ls -la "$DEV_HOME" | head -10 | sed 's/^/  /'
            local total_items=$(ls -1a "$DEV_HOME" | wc -l)
            if [[ $total_items -gt 10 ]]; then
                echo "  ... ($(($total_items - 10)) more items)"
            fi
        else
            echo "  Home directory not found"
        fi

        echo ""
        echo "User Permissions:"
        echo "  Sudo access: $(groups "$DEV_USERNAME" 2>/dev/null | grep -q sudo && echo "Yes" || echo "No")"
        echo "  Docker access: $(groups "$DEV_USERNAME" 2>/dev/null | grep -q docker && echo "Yes" || echo "No")"
        echo "  Development group: $(groups "$DEV_USERNAME" 2>/dev/null | grep -q "$DEV_GROUP" && echo "Yes" || echo "No")"
    else
        echo "[DRY RUN] User information would be displayed here"
    fi

    echo ""
    echo "Configuration Files:"
    local config_files=(".bashrc" ".profile" ".gitconfig" ".vimrc" ".bash_aliases")
    for file in "${config_files[@]}"; do
        local full_path="$DEV_HOME/$file"
        if [[ -f "$full_path" ]]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (missing)"
        fi
    done

    log_separator

    # Show usage instructions
    log_info "Usage Instructions:"
    echo "  • Switch to development user: su - $DEV_USERNAME"
    echo "  • Or start new shell as user: sudo -u $DEV_USERNAME -i"
    echo "  • User has sudo privileges for system administration"
    echo "  • Development tools are accessible via group permissions"
    echo "  • Shell configuration includes development aliases and environment"
}

# =============================================================================
# Utility Functions
# =============================================================================

test_user_environment() {
    local test_user="${1:-$DEV_USERNAME}"

    log_info "Testing user environment for: $test_user"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would test user environment"
        return 0
    fi

    if ! check_user_exists "$test_user"; then
        log_error "User does not exist: $test_user"
        return 1
    fi

    # Test basic shell access
    if sudo -u "$test_user" -i bash -c 'echo "Shell access test"' >/dev/null 2>&1; then
        log_success "Shell access: OK"
    else
        log_error "Shell access: FAILED"
        return 1
    fi

    # Test home directory access
    if sudo -u "$test_user" -i bash -c 'ls ~ >/dev/null'; then
        log_success "Home directory access: OK"
    else
        log_error "Home directory access: FAILED"
        return 1
    fi

    # Test sudo access
    if sudo -u "$test_user" -i bash -c 'sudo -n true' >/dev/null 2>&1; then
        log_success "Sudo access: OK (passwordless)"
    elif sudo -u "$test_user" -i bash -c 'sudo -l' >/dev/null 2>&1; then
        log_success "Sudo access: OK (with password)"
    else
        log_warn "Sudo access: Limited or not configured"
    fi

    log_success "User environment test completed"
    return 0
}

cleanup_user_environment() {
    local user_to_cleanup="${1:-$DEV_USERNAME}"

    log_warn "Cleaning up user environment for: $user_to_cleanup"

    if ! confirm_action "This will remove user $user_to_cleanup and their home directory. Continue?" "n"; then
        log_info "Cleanup cancelled"
        return 0
    fi

     if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would cleanup user: $user_to_cleanup"
        return 0
    fi

    # Stop any processes owned by the user
    if check_user_exists "$user_to_cleanup"; then
        log_info "Stopping processes owned by user..."
        pkill -u "$user_to_cleanup" 2>/dev/null || log_debug "No processes to kill"
        sleep 2
        pkill -9 -u "$user_to_cleanup" 2>/dev/null || log_debug "No processes to force kill"
    fi

    # Remove user and home directory
    if userdel -r "$user_to_cleanup" 2>/dev/null; then
        log_success "User $user_to_cleanup removed successfully"
    else
        log_error "Failed to remove user: $user_to_cleanup"
        return 1
    fi

    # Remove development group if it's empty
    if check_group_exists "$DEV_GROUP"; then
        local group_members=$(getent group "$DEV_GROUP" | cut -d: -f4)
        if [[ -z "$group_members" ]]; then
            if groupdel "$DEV_GROUP" 2>/dev/null; then
                log_info "Empty development group removed: $DEV_GROUP"
            else
                log_warn "Failed to remove development group: $DEV_GROUP"
            fi
        else
            log_info "Development group has other members, keeping: $DEV_GROUP"
        fi
    fi

    log_success "User cleanup completed"
    return 0
}

# Add these utility functions if they don't exist:

check_user_exists() {
    local username="$1"
    id "$username" >/dev/null 2>&1
}

check_group_exists() {
    local groupname="$1"
    getent group "$groupname" >/dev/null 2>&1
}

create_user_if_not_exists() {
    local username="$1"
    local uid="$2"
    local gid="$3"
    local home_dir="$4"
    local shell="$5"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create user: $username"
        return 0
    fi

    useradd -u "$uid" -g "$gid" -d "$home_dir" -s "$shell" -m "$username"
}

create_directory() {
    local dir_path="$1"
    local ownership="$2"
    local permissions="$3"

    mkdir -p "$dir_path"
    if [[ -n "$ownership" ]]; then
        chown "$ownership" "$dir_path"
    fi
    if [[ -n "$permissions" ]]; then
        chmod "$permissions" "$dir_path"
    fi
}

confirm_action() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        return 0
    fi

    local response
    read -p "$prompt [y/N]: " response
    response=${response:-$default}

    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}
# =============================================================================
# Troubleshooting Functions
# =============================================================================

diagnose_user_issues() {
    log_header "User Configuration Diagnostics"

    echo "User Information:"
    if check_user_exists "$DEV_USERNAME"; then
        echo "  ✓ User exists: $DEV_USERNAME"
        echo "  UID: $(id -u "$DEV_USERNAME")"
        echo "  GID: $(id -g "$DEV_USERNAME")"
        echo "  Home: $(getent passwd "$DEV_USERNAME" | cut -d: -f6)"
        echo "  Shell: $(getent passwd "$DEV_USERNAME" | cut -d: -f7)"
    else
        echo "  ✗ User does not exist: $DEV_USERNAME"
    fi

    echo ""
    echo "Group Information:"
    if check_group_exists "$DEV_GROUP"; then
        echo "  ✓ Development group exists: $DEV_GROUP"
        echo "  GID: $(getent group "$DEV_GROUP" | cut -d: -f3)"
        local members=$(getent group "$DEV_GROUP" | cut -d: -f4)
        echo "  Members: ${members:-none}"
    else
        echo "  ✗ Development group does not exist: $DEV_GROUP"
    fi

    echo ""
    echo "System Groups:"
    local system_groups=("sudo" "docker" "www-data")
    for group in "${system_groups[@]}"; do
        if check_group_exists "$group"; then
            echo "  ✓ $group (exists)"
            if check_user_exists "$DEV_USERNAME" && groups "$DEV_USERNAME" | grep -q "\b$group\b"; then
                echo "    - User is member"
            else
                echo "    - User is NOT member"
            fi
        else
            echo "  ✗ $group (missing)"
        fi
    done

    echo ""
    echo "Home Directory:"
    if [[ -d "$DEV_HOME" ]]; then
        echo "  ✓ Home directory exists: $DEV_HOME"
        echo "  Owner: $(stat -c '%U:%G' "$DEV_HOME")"
        echo "  Permissions: $(stat -c '%a' "$DEV_HOME")"

        echo "  Configuration files:"
        local config_files=(".bashrc" ".profile" ".gitconfig" ".vimrc")
        for file in "${config_files[@]}"; do
            local full_path="$DEV_HOME/$file"
            if [[ -f "$full_path" ]]; then
                echo "    ✓ $file ($(stat -c '%a' "$full_path"))"
            else
                echo "    ✗ $file (missing)"
            fi
        done
    else
        echo "  ✗ Home directory does not exist: $DEV_HOME"
    fi

    echo ""
    echo "Permissions Test:"
    if check_user_exists "$DEV_USERNAME"; then
        # Test sudo access
        if sudo -u "$DEV_USERNAME" sudo -n true 2>/dev/null; then
            echo "  ✓ Passwordless sudo access"
        elif sudo -u "$DEV_USERNAME" sudo -l >/dev/null 2>&1; then
            echo "  ✓ Sudo access (password required)"
        else
            echo "  ✗ No sudo access"
        fi

        # Test home directory write access
        if sudo -u "$DEV_USERNAME" touch "$DEV_HOME/.test_write" 2>/dev/null; then
            sudo -u "$DEV_USERNAME" rm -f "$DEV_HOME/.test_write"
            echo "  ✓ Home directory write access"
        else
            echo "  ✗ Home directory write access failed"
        fi

        # Test conda access (if conda exists)
        if [[ -d "${CONDA_PATH:-/opt/conda}" ]]; then
            if sudo -u "$DEV_USERNAME" test -r "${CONDA_PATH:-/opt/conda}/bin/conda"; then
                echo "  ✓ Conda access"
            else
                echo "  ✗ Conda access failed"
            fi
        fi
    else
        echo "  ✗ Cannot test permissions (user does not exist)"
    fi

    log_separator
}

fix_common_user_issues() {
    log_header "Fixing Common User Issues"

    local issues_fixed=0

    # Fix 1: Ensure user exists with correct UID/GID
    if ! check_user_exists "$DEV_USERNAME"; then
        log_info "Issue: User does not exist"
        if confirm_action "Create user $DEV_USERNAME?" "y"; then
            create_development_user && ((issues_fixed++))
        fi
    fi

    # Fix 2: Ensure development group exists
    if ! check_group_exists "$DEV_GROUP"; then
        log_info "Issue: Development group does not exist"
        if confirm_action "Create group $DEV_GROUP?" "y"; then
            create_development_group && ((issues_fixed++))
        fi
    fi

    # Fix 3: Fix home directory ownership
    if [[ -d "$DEV_HOME" ]]; then
        local current_owner=$(stat -c '%U:%G' "$DEV_HOME")
        if [[ "$current_owner" != "$DEV_USERNAME:$DEV_GROUP" ]]; then
            log_info "Issue: Incorrect home directory ownership ($current_owner)"
            if confirm_action "Fix home directory ownership?" "y"; then
                chown -R "$DEV_USERNAME:$DEV_GROUP" "$DEV_HOME" && ((issues_fixed++))
            fi
        fi
    fi

    # Fix 4: Ensure user is in required groups
    if check_user_exists "$DEV_USERNAME"; then
        local user_groups=$(groups "$DEV_USERNAME" 2>/dev/null | cut -d: -f2)
        local missing_groups=()

        for group in "sudo" "$DEV_GROUP"; do
            if ! echo "$user_groups" | grep -q "\b$group\b"; then
                missing_groups+=("$group")
            fi
        done

        if [[ ${#missing_groups[@]} -gt 0 ]]; then
            log_info "Issue: User missing from groups: ${missing_groups[*]}"
            if confirm_action "Add user to missing groups?" "y"; then
                for group in "${missing_groups[@]}"; do
                    if check_group_exists "$group"; then
                        add_user_to_group "$DEV_USERNAME" "$group" && ((issues_fixed++))
                    fi
                done
            fi
        fi
    fi

    # Fix 5: Recreate missing configuration files
    local config_files=(".bashrc" ".profile")
    for file in "${config_files[@]}"; do
        local full_path="$DEV_HOME/$file"
        if [[ ! -f "$full_path" ]]; then
            log_info "Issue: Missing configuration file: $file"
            if confirm_action "Recreate $file?" "y"; then
                case "$file" in
                    ".bashrc") create_user_bashrc && ((issues_fixed++)) ;;
                    ".profile") create_user_profile && ((issues_fixed++)) ;;
                esac
            fi
        fi
    done

    if [[ $issues_fixed -gt 0 ]]; then
        log_success "Fixed $issues_fixed user issues"
    else
        log_info "No issues found or no fixes applied"
    fi

    return 0
}

# =============================================================================
# Export Functions
# =============================================================================

# Export utility functions for use in other modules
export -f test_user_environment cleanup_user_environment
export -f diagnose_user_issues fix_common_user_issues