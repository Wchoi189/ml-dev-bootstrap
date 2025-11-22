#!/bin/bash
# =============================================================================
# Context Management - Centralized Path Resolution and Config Loading
# =============================================================================
# This module provides a single source of truth for project environment setup.
# It eliminates brittle relative path logic scattered across files.
#
# Key Responsibilities:
# 1. Reliable project root resolution
# 2. Configuration loading with override support
# 3. Standard global variable exports
# 4. Idempotent sourcing protection
# =============================================================================

set -euo pipefail

# Idempotency guard - prevent multiple sourcing
if [[ -n "${_CONTEXT_LOADED:-}" ]]; then
    return 0
fi

# =============================================================================
# Path Resolution Functions
# =============================================================================

# Resolve the repository root directory
# Tries git first, falls back to script location
resolve_repo_root() {
    local repo_root=""

    # Try git first (most reliable in git repositories)
    if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        repo_root="$(git rev-parse --show-toplevel)"
    else
        # Fallback to script directory resolution
        # Assumes context.sh is in lib/ directory at project root
        repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    fi

    echo "$repo_root"
}

# =============================================================================
# Configuration Loading
# =============================================================================

# Load configuration files with override support
# Priority: config/local.conf > config/defaults.conf
load_config() {
    local repo_root="$1"
    local config_dir="$repo_root/config"
    local defaults_conf="$config_dir/defaults.conf"
    local local_conf="$config_dir/local.conf"

    # Load defaults first
    if [[ -f "$defaults_conf" ]]; then
        # shellcheck source=/dev/null
        source "$defaults_conf"
    else
        echo "[WARN] defaults.conf not found at: $defaults_conf" >&2
    fi

    # Load local overrides if they exist
    if [[ -f "$local_conf" ]]; then
        # shellcheck source=/dev/null
        source "$local_conf"
        echo "[INFO] Local configuration overrides loaded from: $local_conf" >&2
    fi
}

# =============================================================================
# Initialize Context
# =============================================================================

# Resolve repository root
export REPO_ROOT
REPO_ROOT="$(resolve_repo_root)"

# Set standard directory paths
export CONFIG_DIR="$REPO_ROOT/config"
export MODULES_DIR="$REPO_ROOT/modules"
export UTILS_DIR="$REPO_ROOT/utils"
export LIB_DIR="$REPO_ROOT/lib"

# Load configuration
load_config "$REPO_ROOT"

# Export log file path (use config value if set, otherwise use default)
export LOG_FILE="${LOG_FILE:-$REPO_ROOT/setup-utility.log}"

# Export other commonly used paths
export SCRIPT_DIR="$REPO_ROOT"  # For backward compatibility

# Mark context as loaded
export _CONTEXT_LOADED=1

# =============================================================================
# Verification (Optional - for debugging)
# =============================================================================

# Uncomment for debugging during development
# echo "[DEBUG] Context loaded:"
# echo "  REPO_ROOT: $REPO_ROOT"
# echo "  CONFIG_DIR: $CONFIG_DIR"
# echo "  MODULES_DIR: $MODULES_DIR"
# echo "  UTILS_DIR: $UTILS_DIR"
# echo "  LIB_DIR: $LIB_DIR"
# echo "  LOG_FILE: $LOG_FILE"
