#!/bin/bash
# =============================================================================
# Authentication Utilities - Centralized GitHub Token Management
# =============================================================================
# This module provides centralized authentication logic for GitHub access.
# It ensures consistent token discovery and handling across all modules.
#
# Token Discovery Precedence:
# 1. Environment Variables (GITHUB_PAT, GITHUB_TOKEN, GH_TOKEN)
# 2. Configuration Files (.env.local, .env, config/.env.local)
# 3. Interactive Prompt (optional, if enabled)
#
# Usage:
#   source utils/auth.sh
#   token=$(get_github_token)
# =============================================================================

set -euo pipefail

# =============================================================================
# GitHub Token Discovery
# =============================================================================

# Get GitHub token with proper precedence and error handling
# Returns: GitHub token string (or empty if not found)
# Exit codes:
#   0 - Token found or no token needed
#   1 - Token required but not found (only if interactive mode fails)
get_github_token() {
    local interactive="${1:-false}"  # Optional parameter to enable interactive prompt
    local token=""

    # Step 1: Check environment variables (highest priority)
    token="$(get_token_from_env)"
    if [[ -n "$token" ]]; then
        echo "$token"
        return 0
    fi

    # Step 2: Check configuration files
    token="$(get_token_from_files)"
    if [[ -n "$token" ]]; then
        echo "$token"
        return 0
    fi

    # Step 3: Interactive prompt (if enabled)
    if [[ "$interactive" == "true" ]]; then
        token="$(prompt_for_token)"
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
    fi

    # No token found
    return 0
}

# Get token from environment variables
get_token_from_env() {
    local env_vars=("GITHUB_PAT" "GITHUB_TOKEN" "GH_TOKEN")

    for var in "${env_vars[@]}"; do
        local value="${!var:-}"
        if [[ -n "$value" ]]; then
            if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
                echo "[DEBUG] Found GitHub token in environment variable: $var" >&2
            fi
            echo "$value"
            return 0
        fi
    done

    return 1
}

# Get token from configuration files
get_token_from_files() {
    local candidates=()

    # Add explicit token file if specified
    if [[ -n "${GITHUB_TOKEN_FILE:-}" ]]; then
        candidates+=("$GITHUB_TOKEN_FILE")
    fi

    # Add standard locations
    # Use REPO_ROOT if available (from context.sh), otherwise fallback to SCRIPT_DIR
    local base_dir="${REPO_ROOT:-${SCRIPT_DIR:-.}}"
    candidates+=(
        "$base_dir/.env.local"
        "$base_dir/.env"
        "$base_dir/config/.env.local"
    )

    for file in "${candidates[@]}"; do
        [[ -f "$file" ]] || continue

        local line
        line="$(grep -E '^GITHUB_(PAT|TOKEN)[:=]' "$file" | tail -n1 || true)"
        [[ -z "$line" ]] && continue

        local token_raw
        if [[ "$line" == *"="* ]]; then
            token_raw="${line#*=}"
        else
            token_raw="${line#*:}"
        fi

        # Remove quotes and trim whitespace
        token_raw="${token_raw//\"/}"
        token_raw="${token_raw//\'/}"
        local token
        token="$(echo "$token_raw" | xargs)"

        if [[ -n "$token" ]]; then
            if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
                echo "[DEBUG] Loaded GitHub token from: $file" >&2
            fi
            echo "$token"
            return 0
        fi
    done

    return 1
}

# Prompt user for token interactively
prompt_for_token() {
    echo "[INFO] No GitHub token found in environment or config files" >&2
    echo "[INFO] Please enter your GitHub Personal Access Token (PAT):" >&2
    echo "[INFO] (Leave empty to skip authentication)" >&2

    local token
    read -r -s -p "Token: " token
    echo "" >&2  # New line after hidden input

    if [[ -n "$token" ]]; then
        echo "[INFO] Token received (will be used for this session only)" >&2
        echo "$token"
        return 0
    fi

    return 1
}

# =============================================================================
# Token Validation
# =============================================================================

# Validate GitHub token format
# Returns: 0 if valid, 1 if invalid
validate_github_token() {
    local token="$1"

    if [[ -z "$token" ]]; then
        return 1
    fi

    # GitHub PATs typically start with:
    # - ghp_ (personal access token - fine-grained)
    # - github_pat_ (personal access token)
    # - gho_ (OAuth token)
    # - ghu_ (user-to-server token)
    # - ghs_ (server-to-server token)
    # - ghr_ (refresh token)
    if [[ "$token" =~ ^(ghp_|github_pat_|gho_|ghu_|ghs_|ghr_) ]]; then
        return 0
    fi

    # Legacy format (40 character hex string)
    if [[ "$token" =~ ^[0-9a-f]{40}$ ]]; then
        return 0
    fi

    # If it doesn't match known patterns, still return success
    # (GitHub may introduce new token formats)
    return 0
}

# =============================================================================
# Helper Functions
# =============================================================================

# Check if user is authenticated with gh CLI
is_gh_authenticated() {
    local user="${1:-$(whoami)}"

    if ! command -v gh &>/dev/null; then
        return 1
    fi

    if [[ "$user" == "root" ]]; then
        gh auth status &>/dev/null
    else
        su - "$user" -c "gh auth status" &>/dev/null 2>&1
    fi
}

# Save token to user's git credentials (for HTTPS operations)
save_token_to_git_credentials() {
    local token="$1"
    local user="${2:-$(whoami)}"
    local home_dir

    if [[ "$user" == "root" ]]; then
        home_dir="$HOME"
    else
        home_dir="/home/$user"
    fi

    local creds_file="$home_dir/.git-credentials"

    # Configure credential helper
    if [[ "$user" == "root" ]]; then
        git config --global credential.helper store
    else
        su - "$user" -c "git config --global credential.helper store"
    fi

    # Write credentials
    echo "https://oauth2:$token@github.com" > "$creds_file"
    chmod 600 "$creds_file"

    if [[ "$user" != "root" ]]; then
        chown "$user:$user" "$creds_file" 2>/dev/null || true
    fi

    return 0
}

# =============================================================================
# Backward Compatibility Aliases
# =============================================================================

# Alias for ghcli.sh compatibility
ghcli_discover_token() {
    get_github_token
}

# Alias for git.sh compatibility
discover_github_token() {
    get_github_token
}
