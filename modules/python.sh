#!/bin/bash
# =============================================================================
# Python Environment Setup Module (pyenv + poetry)
# =============================================================================

# Resolve directories robustly and source config
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"

setup_python_env() {
    # Install pyenv and Python version if enabled
    source "$MODULE_DIR/pyenv.sh"
    install_pyenv

    # Install Poetry if enabled
    source "$MODULE_DIR/poetry.sh"
    install_poetry

    # Install Pipenv if enabled
    source "$MODULE_DIR/pipenv.sh"
    install_pipenv
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    setup_python_env
fi
