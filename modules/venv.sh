#!/bin/bash
# =============================================================================
# Virtual Environment Auto-Activation Bashrc Module
# =============================================================================

# Resolve directories robustly
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"

# Directory where venvs are expected (can be customized)
WORKSPACE_DIR="$HOME/workspace"
VENV_NAME=".venv"

add_auto_venv_bashrc() {
    if [[ "$ENABLE_AUTO_VENV_BASHRC" != "yes" ]]; then
        echo "[venv] Skipping bashrc auto-activation (ENABLE_AUTO_VENV_BASHRC=$ENABLE_AUTO_VENV_BASHRC)"
        return 0
    fi
    local bashrc="$HOME/.bashrc"
    local marker="# >>> ml-dev-bootstrap venv auto-activation >>>"
    local end_marker="# <<< ml-dev-bootstrap venv auto-activation <<<"
    # Remove old block if present
    sed -i "/$marker/,/$end_marker/d" "$bashrc"
    # Add new block
    cat <<EOF >> "$bashrc"
$marker
function _ml_dev_auto_venv() {
    if [[ "$PWD" == "$WORKSPACE_DIR"* ]]; then
        if [[ -d "$WORKSPACE_DIR/$VENV_NAME" ]]; then
            if [[ -z "${VIRTUAL_ENV:-}" ]]; then
                source "$WORKSPACE_DIR/$VENV_NAME/bin/activate"
            fi
        fi
    else
        if [[ -n "${VIRTUAL_ENV:-}" ]]; then
            deactivate
        fi
    fi
}
PROMPT_COMMAND="_ml_dev_auto_venv; $PROMPT_COMMAND"
$end_marker
EOF
    echo "[venv] .bashrc updated for auto venv activation."
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    add_auto_venv_bashrc
fi
