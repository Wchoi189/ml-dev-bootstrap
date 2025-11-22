#!/bin/bash
# =============================================================================
# Module Bootstrap Header
# Standard initialization for all module scripts
# =============================================================================
# This file provides a standardized initialization for all modules.
# It ensures that every module has access to:
# - Centralized context (path resolution, config loading)
# - Standard logging functions
# - Error handling and cleanup
#
# Usage in modules:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap_module.sh"
# =============================================================================

set -euo pipefail

# =============================================================================
# Context Loading
# =============================================================================

# Determine the directory of the bootstrap script
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source centralized context
# shellcheck source=./context.sh
source "$BOOTSTRAP_DIR/context.sh"

# =============================================================================
# Logging Initialization
# =============================================================================

# Source logging utilities if available
if [[ -f "$UTILS_DIR/logger.sh" ]]; then
    # shellcheck source=../utils/logger.sh
    source "$UTILS_DIR/logger.sh"
else
    # Fallback: define basic logging functions if logger.sh is not available
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
    log_debug() { [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]] && echo "[DEBUG] $*" >&2 || true; }
    log_header() { echo ""; echo "=== $* ==="; echo ""; }
    log_separator() { echo "----------------------------------------"; }
    log_step() { local step=$1; local total=$2; shift 2; echo "[$step/$total] $*"; }
fi

# =============================================================================
# Error Handling
# =============================================================================

# Error trap handler for modules
module_error_handler() {
    local exit_code=$?
    local line_number=$1
    local module_name="${BASH_SOURCE[2]:-unknown_module}"

    if [[ $exit_code -ne 0 ]]; then
        log_error "Module failed: $module_name at line $line_number (exit code: $exit_code)"
    fi

    return $exit_code
}

# Set up error trap
trap 'module_error_handler $LINENO' ERR

# =============================================================================
# Cleanup Handler
# =============================================================================

# Cleanup function that modules can override or extend
module_cleanup() {
    # Default cleanup - modules can override this
    log_debug "Module cleanup complete"
}

# Set up exit trap for cleanup
trap module_cleanup EXIT

# =============================================================================
# Common Utilities Loading
# =============================================================================

# Source common utilities if available
if [[ -f "$UTILS_DIR/common.sh" ]]; then
    # shellcheck source=../utils/common.sh
    source "$UTILS_DIR/common.sh"
fi

# =============================================================================
# Module Context Variables
# =============================================================================

# Export module-specific variables that may be needed
export MODULE_NAME="${BASH_SOURCE[1]##*/}"  # Name of the module file
export MODULE_NAME="${MODULE_NAME%.sh}"      # Remove .sh extension
export MODULE_DIR="$MODULES_DIR"             # Modules directory from context

# =============================================================================
# Verification (for debugging)
# =============================================================================

# Uncomment for debugging during development
# log_debug "Bootstrap loaded for module: $MODULE_NAME"
# log_debug "  REPO_ROOT: $REPO_ROOT"
# log_debug "  CONFIG_DIR: $CONFIG_DIR"
# log_debug "  MODULES_DIR: $MODULES_DIR"
# log_debug "  UTILS_DIR: $UTILS_DIR"
