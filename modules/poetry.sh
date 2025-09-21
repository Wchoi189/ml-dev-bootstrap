#!/bin/bash
# =============================================================================
# Poetry Installation Module
# =============================================================================

# Resolve directories robustly even when sourced
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"

# Load config safely while preserving pre-set env overrides
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
_PRIOR_INSTALL_POETRY="${INSTALL_POETRY-}"
_PRIOR_POETRY_HOME="${POETRY_HOME-}"
_PRIOR_POETRY_INSTALL_MODE="${POETRY_INSTALL_MODE-}"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"
[[ -n "${_PRIOR_INSTALL_POETRY}" ]] && export INSTALL_POETRY="${_PRIOR_INSTALL_POETRY}"
[[ -n "${_PRIOR_POETRY_HOME}" ]] && export POETRY_HOME="${_PRIOR_POETRY_HOME}"
[[ -n "${_PRIOR_POETRY_INSTALL_MODE}" ]] && export POETRY_INSTALL_MODE="${_PRIOR_POETRY_INSTALL_MODE}"

install_poetry() {
    # Respect toggle. Return 2 to indicate skipped by config.
    if [[ "${INSTALL_POETRY:-no}" != "yes" ]]; then
        log_info "[poetry] Skipping Poetry (INSTALL_POETRY=${INSTALL_POETRY:-no})"
        return 2
    fi

    # Determine install mode
    # system: shared under /opt with dev group permissions
    # user:   install for configured user (USERNAME) home
    local install_mode="${POETRY_INSTALL_MODE:-system}"
    local dev_group="${USER_GROUP:-vscode}"
    local dev_user="${USERNAME-}"

    # Ensure python3 is present
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "[poetry] python3 not found; install Python before Poetry"
        return 1
    fi

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
            log_warn "[poetry] System install requested but not running as root; falling back to user install"
            install_mode="user"
        fi
    fi

    if [[ "$install_mode" == "system" ]]; then
        local opt_home="${POETRY_HOME:-/opt/pypoetry}"
        log_info "[poetry] Installing system-wide to $opt_home (group: $dev_group)"

        # Ensure dev group exists
        if ! getent group "$dev_group" >/dev/null 2>&1; then
            log_info "[poetry] Creating dev group '$dev_group'"
            groupadd "$dev_group" || true
        fi

        # Ensure basic dependencies are present
        log_debug "[poetry] Installing system dependencies..."
        if command -v apt >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt update -y >/dev/null 2>&1 || true
            DEBIAN_FRONTEND=noninteractive apt install -y curl ca-certificates python3-venv python3-pip >/dev/null 2>&1 || true
            log_debug "[poetry] System dependencies installed"
        fi

        umask 002
        log_debug "[poetry] Creating installation directories..."
        mkdir -p "$opt_home" "$opt_home/bin"

        # Try official installer first
        log_info "[poetry] Attempting official Poetry installer..."
        if env POETRY_HOME="$opt_home" bash -lc 'curl -sSL https://install.python-poetry.org | python3 -'; then
            log_success "[poetry] Official installer succeeded"
            : # success
        else
            log_warn "[poetry] Official installer failed; attempting venv-based fallback"
            log_debug "[poetry] Creating Python virtual environment..."
            # Fallback: install Poetry into a dedicated venv under /opt/pypoetry/venv
            if python3 -m venv "$opt_home/venv" 2>/dev/null; then
                log_debug "[poetry] Upgrading pip and installing Poetry..."
                "$opt_home/venv/bin/python" -m pip install --upgrade pip wheel >/dev/null 2>&1 || true
                if "$opt_home/venv/bin/python" -m pip install --upgrade poetry >/dev/null 2>&1; then
                    log_debug "[poetry] Creating symlink to Poetry binary..."
                    ln -sf "$opt_home/venv/bin/poetry" "$opt_home/bin/poetry"
                    log_success "[poetry] Venv-based fallback succeeded"
                else
                    log_error "[poetry] Fallback pip install failed"
                    return 1
                fi
            else
                log_error "[poetry] Failed to create venv for fallback"
                return 1
            fi
        fi

        # Ensure permissions and PATH exposure
        log_debug "[poetry] Setting up permissions and PATH..."
        ensure_dev_group_perms "$opt_home" "$dev_group"

        # Symlink binary into /usr/local/bin for all users
        mkdir -p /usr/local/bin
        ln -sf "$opt_home/bin/poetry" /usr/local/bin/poetry

        # Profile script to ensure PATH (defensive)
        local profile_script="/etc/profile.d/poetry.sh"
        if [[ ! -f "$profile_script" ]]; then
            echo 'export PATH="/opt/pypoetry/bin:$PATH"' > "$profile_script"
            chmod 644 "$profile_script"
        fi

        # Verify
        if ! command -v poetry >/dev/null 2>&1; then
            export PATH="/opt/pypoetry/bin:$PATH"
        fi
        if ! poetry --version >/dev/null 2>&1; then
            log_error "[poetry] Verification failed"
            return 1
        fi

        log_success "[poetry] Installed system-wide at $opt_home"
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
    log_info "[poetry] Installing for user: $target_user ($target_home)"

    # If poetry already available, skip
    if sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'command -v poetry >/dev/null 2>&1'; then
        log_info "[poetry] Poetry already installed for $target_user"
        return 0
    fi

    if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'curl -sSL https://install.python-poetry.org | python3 -'; then
        log_error "[poetry] Installation script failed for $target_user"
        return 1
    fi

    # Ensure user's local bin on PATH for interactive shells
    local bashrc="$target_home/.bashrc"
    if ! grep -q 'export PATH=.*/.local/bin' "$bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$bashrc"
    fi

    # Group perms so other devs can execute if symlinked
    ensure_dev_group_perms "$target_home/.local" "$dev_group"

    # Optionally symlink to /usr/local/bin for convenience (root only)
    if [[ $EUID -eq 0 && -x "$target_home/.local/bin/poetry" ]]; then
        ln -sf "$target_home/.local/bin/poetry" /usr/local/bin/poetry
    fi

    # Verify
    if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'poetry --version >/dev/null'; then
        log_error "[poetry] Verification failed for $target_user"
        return 1
    fi
    log_success "[poetry] Installed for $target_user"
    return 0
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    install_poetry
fi
