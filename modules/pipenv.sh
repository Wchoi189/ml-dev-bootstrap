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
        echo "[pipenv] Skipping Pipenv installation (INSTALL_PIPENV=${INSTALL_PIPENV:-no})"
        return 2
    fi

    local dev_group="${USER_GROUP:-dev}"
    local dev_user="${USERNAME-}"
    local target_user target_home
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

    if command -v pipenv >/dev/null 2>&1; then
        echo "[pipenv] Pipenv already installed."
        return 0
    fi

    echo "[pipenv] Installing Pipenv for $target_user..."
    if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'python3 -m pip install --user --upgrade pipenv'; then
        echo "[pipenv] Installation failed"
        return 1
    fi

    # Ensure PATH for user shells
    if ! grep -q 'export PATH=.*/.local/bin' "$target_home/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$target_home/.bashrc"
    fi

    # Group permissions and optional system symlink
    if [[ -d "$target_home/.local" ]]; then
        chgrp -R "$dev_group" "$target_home/.local" 2>/dev/null || true
        chmod -R g+rwX "$target_home/.local" 2>/dev/null || true
        find "$target_home/.local" -type d -exec chmod g+s {} + 2>/dev/null || true
    fi
    if [[ $EUID -eq 0 && -x "$target_home/.local/bin/pipenv" ]]; then
        ln -sf "$target_home/.local/bin/pipenv" /usr/local/bin/pipenv
    fi

    if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'pipenv --version >/dev/null'; then
        echo "[pipenv] Verification failed"
        return 1
    fi
    echo "[pipenv] Installed for $target_user"
    return 0
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    install_pipenv
fi
