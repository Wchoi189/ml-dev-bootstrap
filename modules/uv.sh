#!/bin/bash
# =============================================================================
# UV Installation Module
# Fast Python package installer and resolver
# =============================================================================

# Resolve directories robustly even when sourced
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"

# Load config safely while preserving pre-set env overrides
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
_PRIOR_INSTALL_UV="${INSTALL_UV-}"
_PRIOR_UV_INSTALL_MODE="${UV_INSTALL_MODE-}"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"
[[ -n "${_PRIOR_INSTALL_UV}" ]] && export INSTALL_UV="${_PRIOR_INSTALL_UV}"
[[ -n "${_PRIOR_UV_INSTALL_MODE}" ]] && export UV_INSTALL_MODE="${_PRIOR_UV_INSTALL_MODE}"

install_uv() {
    # Respect toggle. Return 2 to indicate skipped by config.
    if [[ "${INSTALL_UV:-no}" != "yes" ]]; then
        log_info "[uv] Skipping UV (INSTALL_UV=${INSTALL_UV:-no})"
        return 2
    fi

    # Determine install mode
    # system: shared under /opt with dev group permissions
    # user:   install for configured user (USERNAME) home
    local install_mode="${UV_INSTALL_MODE:-system}"
    local dev_group="${USER_GROUP:-vscode}"
    local dev_user="${USERNAME-}"

    # Helper to apply dev group permissions to a directory tree
    ensure_dev_group_perms() {
        local path="$1"
        local group="$2"
        [[ -d "$path" ]] || return 0
        chgrp -R "$group" "$path" || true
        chmod -R g+rwX "$path" || true
        find "$path" -type d -exec chmod g+s {} + 2>/dev/null || true
    }

    # System-wide install (preferred for multi-user)
    if [[ "$install_mode" == "system" ]]; then
        if [[ $EUID -ne 0 ]]; then
            log_warn "[uv] System install requested but not running as root; falling back to user install"
            install_mode="user"
        fi
    fi

    if [[ "$install_mode" == "system" ]]; then
        local opt_home="/opt/uv/bin"
        log_info "[uv] Installing system-wide to $opt_home (group: $dev_group)"

        # Ensure dev group exists
        if ! getent group "$dev_group" >/dev/null 2>&1; then
            log_info "[uv] Creating dev group '$dev_group'"
            groupadd "$dev_group" || true
        fi

        # Ensure basic dependencies are present
        log_debug "[uv] Installing system dependencies..."
        if command -v apt >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt update -y >/dev/null 2>&1 || true
            DEBIAN_FRONTEND=noninteractive apt install -y curl ca-certificates >/dev/null 2>&1 || true
            log_debug "[uv] System dependencies installed"
        fi

        umask 002
        log_debug "[uv] Creating installation directories..."
        mkdir -p "$opt_home"

        # Install UV using the official installer
        log_info "[uv] Installing UV using official installer..."
        if curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$opt_home" sh; then
            log_success "[uv] Official installer succeeded"
        else
            log_error "[uv] Official installer failed"
            return 1
        fi

        # Ensure permissions and PATH exposure
        log_debug "[uv] Setting up permissions and PATH..."
        ensure_dev_group_perms "$opt_home" "$dev_group"

        # Detect where the binary actually landed
        local uv_bin_path="$opt_home/uv"
        local uvx_bin_path="$opt_home/uvx"
        local uv_install_dir="$opt_home"

        if [[ ! -f "$uv_bin_path" ]]; then
             log_warn "[uv] Binary not found at expected path: $uv_bin_path"
        fi

        # Symlink binary into /usr/local/bin for all users
        mkdir -p /usr/local/bin
        ln -sf "$uv_bin_path" /usr/local/bin/uv
        ln -sf "$uvx_bin_path" /usr/local/bin/uvx

        # Profile script to ensure PATH (defensive)
        local profile_script="/etc/profile.d/uv.sh"
        if [[ ! -f "$profile_script" ]]; then
            cat > "$profile_script" << EOF
export PATH="$uv_install_dir:\$PATH"
EOF
            chmod 644 "$profile_script"
        fi

        # Verify
        if ! command -v uv >/dev/null 2>&1; then
            export PATH="$uv_install_dir:$PATH"
        fi
        if ! uv --version >/dev/null 2>&1; then
            log_error "[uv] Verification failed"
            return 1
        fi

        log_success "[uv] Installed system-wide at $opt_home"
        return 0
    fi

    # User install (install for configured user or current user)
    local target_user
    local target_home
    if [[ -n "$dev_user" ]] && id "$dev_user" &>/dev/null; then
        target_user="$dev_user"
        target_home="/home/$dev_user"
    elif [[ $EUID -eq 0 ]]; then
        target_user="root"
        target_home="/root"
    else
        target_user="$(id -un)"
        target_home="$HOME"
    fi
    log_info "[uv] Installing for user: $target_user ($target_home)"

    # If uv already available, skip
    if [[ "$(id -un)" == "$target_user" ]]; then
        # We're already the target user, check directly
        if command -v uv >/dev/null 2>&1; then
            log_info "[uv] UV already installed for $target_user"
            return 0
        fi
    else
        # Check as target user
        if sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'command -v uv >/dev/null 2>&1'; then
            log_info "[uv] UV already installed for $target_user"
            return 0
        fi
    fi

    # Install UV for the user
    log_info "[uv] Installing UV for $target_user..."
    if [[ "$(id -un)" == "$target_user" ]]; then
        # We're already the target user, install directly
        if ! curl -LsSf https://astral.sh/uv/install.sh | sh; then
            log_error "[uv] Installation failed for $target_user"
            return 1
        fi
    else
        # Install as target user
        if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'; then
            log_error "[uv] Installation failed for $target_user"
            return 1
        fi
    fi

    # Ensure user's local bin on PATH for interactive shells
    local bashrc="$target_home/.bashrc"
    if ! grep -q 'export PATH=.*/.local/bin' "$bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$bashrc"
    fi

    # Group perms so other devs can execute if symlinked
    ensure_dev_group_perms "$target_home/.local" "$dev_group"

    # Optionally symlink to /usr/local/bin for convenience (root only)
    if [[ $EUID -eq 0 ]]; then
        if [[ -x "$target_home/.local/bin/uv" ]]; then
            ln -sf "$target_home/.local/bin/uv" /usr/local/bin/uv
        fi
        if [[ -x "$target_home/.local/bin/uvx" ]]; then
            ln -sf "$target_home/.local/bin/uvx" /usr/local/bin/uvx
        fi
    fi

    # Verify
    if [[ "$(id -un)" == "$target_user" ]]; then
        # We're already the target user, verify directly
        if ! uv --version >/dev/null; then
            log_error "[uv] Verification failed for $target_user"
            return 1
        fi
    else
        # Verify as target user
        if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'uv --version >/dev/null'; then
            log_error "[uv] Verification failed for $target_user"
            return 1
        fi
    fi
    log_success "[uv] Installed for $target_user"
    return 0
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    install_uv
fi