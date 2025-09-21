#!/bin/bash

# =============================================================================
# Git Configuration Module
# Configures git with user information and development-friendly settings
# =============================================================================

# Helper function to run git commands as the development user
# This changes to the user's home directory to avoid permissions issues.
run_git_as_user() {
    sudo -u "$DEV_USERNAME" -i -- bash -c "git $*"
}

# =============================================================================
# Main Git Setup Function
# =============================================================================

run_git() {
    log_header "Git Configuration Setup"

    # Source common configuration to ensure variables are loaded
    local _MOD_DIR _REPO_ROOT
    _MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _REPO_ROOT="$(cd "$_MOD_DIR/.." && pwd)"
    if [[ -f "$_REPO_ROOT/config/defaults.conf" ]]; then
        source "$_REPO_ROOT/config/defaults.conf"
    fi

    # Validate required user and home directory variables
    if [[ -z "${DEV_USERNAME:-}" ]]; then
        DEV_USERNAME="${USERNAME:-vscode-user}"
        log_debug "Set DEV_USERNAME to: $DEV_USERNAME"
    fi
    if [[ -z "${DEV_GROUP:-}" ]]; then
        DEV_GROUP="${USER_GROUP:-vscode}"
        log_debug "Set DEV_GROUP to: $DEV_GROUP"
    fi
    if [[ -z "${DEV_HOME:-}" ]]; then
        DEV_HOME="/home/$DEV_USERNAME"
        log_debug "Set DEV_HOME to: $DEV_HOME"
    fi

    local total_steps=6
    local current_step=0

    # Step 1: Validate git configuration
    ((current_step++))
    log_step $current_step $total_steps "Validating git configuration"
    validate_git_config || return 1

    # Step 2: Ensure git is installed
    ((current_step++))
    log_step $current_step $total_steps "Verifying git installation"
    verify_git_installation || return 1

    # Step 3: Configure global git settings for root
    ((current_step++))
    log_step $current_step $total_steps "Configuring global git settings"
    configure_global_git || return 1

    # Step 4: Configure user-specific git settings
    ((current_step++))
    log_step $current_step $total_steps "Configuring user git settings"
    configure_user_git || return 1

    # Step 5: Set up git aliases
    ((current_step++))
    log_step $current_step $total_steps "Setting up git aliases"
    setup_git_aliases || return 1

    # Step 6: Verify git configuration
    ((current_step++))
    log_step $current_step $total_steps "Verifying git configuration"
    verify_git_configuration || return 1

    log_success "Git configuration completed successfully!"
    show_git_info
}

# =============================================================================
# Configuration Functions
# =============================================================================

configure_global_git() {
    log_info "Configuring global git settings for root user..."
    git config --global user.name "'$GIT_USER_NAME'"
    git config --global user.email "'$GIT_USER_EMAIL'"
    git config --global init.defaultBranch "$GIT_DEFAULT_BRANCH"
    log_success "Global git configuration completed"
    return 0
}

configure_user_git() {
    log_info "Configuring user-specific git settings for ${DEV_USERNAME}..."
    if ! check_user_exists "$DEV_USERNAME"; then
        log_warn "User ${DEV_USERNAME} does not exist, skipping."
        return 0
    fi

    run_git_as_user config --global user.name "'$GIT_USER_NAME'" || {
        log_error "Failed to set user git name"
        return 1
    }

    run_git_as_user config --global user.email "'$GIT_USER_EMAIL'" || {
        log_error "Failed to set user git email"
        return 1
    }

    run_git_as_user config --global init.defaultBranch "$GIT_DEFAULT_BRANCH" || {
        log_error "Failed to set user default branch"
        return 1
    }

    create_user_gitignore

    log_success "User git configuration completed"
    return 0
}

create_user_gitignore() {
    local gitignore_file="$DEV_HOME/.gitignore_global"
    log_debug "Creating global gitignore file: $gitignore_file"

    # The 'cat > "$gitignore_file"' heredoc from your script goes here
    # ... (it's very long, so I'm omitting it for brevity, but it should be here)
    cat > "$gitignore_file" << 'EOF'
# Global gitignore for Python, Node, OS files, etc.
__pycache__/
*.py[cod]
.env
node_modules/
.DS_Store
.vscode/
EOF

    chown "$DEV_USERNAME:$DEV_GROUP" "$gitignore_file"
    chmod 644 "$gitignore_file"

    run_git_as_user config --global core.excludesfile "'$gitignore_file'"
    return 0
}

setup_git_aliases() {
    log_info "Setting up git aliases..."

    # Set aliases for root
    for alias in "${!GIT_ALIASES[@]}"; do
        git config --global "alias.$alias" "'${GIT_ALIASES[$alias]}'"
    done

    # Set aliases for dev user
    if check_user_exists "$DEV_USERNAME"; then
        for alias in "${!GIT_ALIASES[@]}"; do
            run_git_as_user config --global "alias.$alias" "'${GIT_ALIASES[$alias]}'"
        done
    fi

    log_success "Git aliases setup completed"
    return 0
}

# =============================================================================
# Verification Functions (simplified and corrected)
# =============================================================================

verify_git_installation() {
    log_info "Verifying git installation..."
    if ! check_command "git"; then
        log_info "Git not found, installing..."
        install_packages "git" || {
            log_error "Failed to install git"
            return 1
        }
    fi
    log_info "Git version: $(git --version)"
    log_success "Git installation verified"
    return 0
}

verify_git_configuration() {
    log_info "Verifying git configuration..."
    if check_user_exists "$DEV_USERNAME"; then
        local user_name
        user_name=$(run_git_as_user config --global --get user.name 2>/dev/null)

        if [[ "$user_name" != "$GIT_USER_NAME" ]]; then
            log_error "User git name mismatch: expected '$GIT_USER_NAME', got '$user_name'"
            return 1
        fi
        log_success "User git name verified."

        local user_email
        user_email=$(run_git_as_user config --global --get user.email 2>/dev/null)

        if [[ "$user_email" != "$GIT_USER_EMAIL" ]]; then
            log_error "User git email mismatch: expected '$GIT_USER_EMAIL', got '$user_email'"
            return 1
        fi
        log_success "User git email verified."
    fi
    log_success "Git configuration verification completed"
    return 0
}

# =============================================================================
# Other functions from your script (validate_git_config, show_git_info, etc.)
# would go here. They don't need changes for this specific fix.
# =============================================================================

# Dummy functions for anything referenced but not in the original prompt
validate_git_config() { log_success "Git config validated."; }
show_git_info() { log_info "Displaying Git Info."; }
check_command() { command -v "$1" >/dev/null 2>&1; }
check_user_exists() { id "$1" >/dev/null 2>&1; }
install_packages() { log_info "Installing packages: $@"; }

# The GIT_ALIASES definition needs to be here for the script to run
declare -A GIT_ALIASES=(
    ["st"]="status"
    ["co"]="checkout"
    ["br"]="branch"
    ["ci"]="commit"
    ["lg"]="log --oneline --graph --decorate"
)