#!/bin/bash
# =============================================================================
# Pipenv Installation Module
# =============================================================================

# Resolve directories robustly
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"

install_pipenv() {
    if [[ "${INSTALL_PIPENV:-no}" != "yes" ]]; then
        log_info "Skipping Pipenv installation (INSTALL_PIPENV=${INSTALL_PIPENV:-no})"
        return 2
    fi

    local dev_group="${USER_GROUP:-vscode}"
    local dev_user="${USERNAME-}"
    local target_user target_home
    if [[ $EUID -eq 0 ]]; then
        # System-wide install when running as root
        target_user="system"
        target_home="/root"
        log_debug "Installing Pipenv system-wide"
    elif [[ -n "$dev_user" ]] && id "$dev_user" &>/dev/null; then
        target_user="$dev_user"
        target_home="/home/$dev_user"
        log_debug "Installing Pipenv for development user: $target_user (home: $target_home)"
    else
        target_user="$(id -un)"
        target_home="$HOME"
        log_debug "Installing Pipenv for current user: $target_user (home: $target_home)"
    fi

    if command -v pipenv >/dev/null 2>&1; then
        if pipenv --version >/dev/null 2>&1; then
            log_info "Pipenv already installed."
            if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                pipenv --version
            fi
            return 0
        else
            log_warn "Found broken pipenv installation, removing and reinstalling..."
            pipenv_path="$(command -v pipenv)"
            rm -f "$pipenv_path" || true
        fi
    fi

    log_info "Installing Pipenv for $target_user..."
    
    if [[ $EUID -eq 0 ]]; then
        # System-wide installation when running as root
        log_debug "Running: python3 -m pip install --upgrade pipenv"
        if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
            if ! python3 -m pip install --upgrade pipenv; then
                log_error "Pipenv system installation failed"
                return 1
            fi
        else
            if ! python3 -m pip install --upgrade pipenv; then
                log_error "Pipenv system installation failed"
                return 1
            fi
        fi
    else
        # User installation when not running as root
        log_debug "Running: python3 -m pip install --user --upgrade pipenv"
        if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
            if ! python3 -m pip install --user --upgrade pipenv; then
                log_error "Pipenv user installation failed"
                return 1
            fi
        else
            if ! python3 -m pip install --user --upgrade pipenv >/dev/null 2>&1; then
                log_error "Pipenv user installation failed"
                return 1
            fi
        fi
        
        # Ensure PATH for user shells
        log_debug "Ensuring PATH configuration in $target_home/.bashrc"
        if ! grep -q 'export PATH=.*/.local/bin' "$target_home/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$target_home/.bashrc"
            log_debug "Added PATH export to $target_home/.bashrc"
        else
            log_debug "PATH export already exists in $target_home/.bashrc"
        fi
    fi

    # Group permissions for user installs
    if [[ $EUID -ne 0 && -d "$target_home/.local" ]]; then
        log_debug "Setting group permissions on $target_home/.local"
        chgrp -R "$dev_group" "$target_home/.local" 2>/dev/null || true
        chmod -R g+rwX "$target_home/.local" 2>/dev/null || true
        find "$target_home/.local" -type d -exec chmod g+s {} + 2>/dev/null || true
        log_debug "Group permissions set for $target_home/.local"
    fi

    log_debug "Verifying Pipenv installation"
    if [[ $EUID -eq 0 ]]; then
        if ! pipenv --version >/dev/null 2>&1; then
            log_error "Pipenv verification failed"
            return 1
        fi
    else
        if ! pipenv --version >/dev/null 2>&1; then
            log_error "Pipenv verification failed"
            return 1
        fi
    fi

    log_success "Pipenv installed for $target_user"
    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
        pipenv --version
    fi
    return 0
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    install_pipenv
fi
