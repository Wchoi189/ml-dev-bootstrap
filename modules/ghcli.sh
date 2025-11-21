#!/bin/bash

# =============================================================================
# GitHub CLI Setup Module
# Installs and optionally authenticates GitHub CLI (gh)
# =============================================================================

GHCLI_KEYRING_PATH="/usr/share/keyrings/githubcli-archive-keyring.gpg"
GHCLI_APT_SOURCE="/etc/apt/sources.list.d/github-cli.list"
GHCLI_COMPLETION_PATH="/etc/bash_completion.d/gh"

run_ghcli() {
    log_header "GitHub CLI Setup"

    ghcli_detect_context

    ghcli_install_prerequisites || return 1
    ghcli_configure_repository || return 1
    ghcli_install_package || return 1
    ghcli_install_completion || log_warn "Unable to install gh completion (non-fatal)"
    ghcli_attempt_authentication
    ghcli_show_summary

    log_success "GitHub CLI setup complete"
    return 0
}

ghcli_detect_context() {
    GHCLI_DEV_USERNAME="${DEV_USERNAME:-${USERNAME:-vscode}}"
    GHCLI_DEV_GROUP="${DEV_GROUP:-${USER_GROUP:-$GHCLI_DEV_USERNAME}}"
    GHCLI_DEV_HOME="/home/$GHCLI_DEV_USERNAME"

    if ! check_user_exists "$GHCLI_DEV_USERNAME"; then
        log_warn "Development user '$GHCLI_DEV_USERNAME' not found; GitHub CLI auth will only run for root"
    fi
}

ghcli_install_prerequisites() {
    local packages=("curl" "ca-certificates" "apt-transport-https" "gnupg" "lsb-release")
    log_info "Ensuring prerequisites for GitHub CLI: ${packages[*]}"
    install_packages "${packages[@]}"
}

ghcli_configure_repository() {
    log_info "Configuring official GitHub CLI apt repository"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install GitHub CLI signing key and repository"
        return 0
    fi

    if [[ ! -f "$GHCLI_KEYRING_PATH" ]]; then
        log_info "Downloading GitHub CLI signing key"
        if ! curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of="$GHCLI_KEYRING_PATH" 2>/dev/null; then
            log_error "Failed to download GitHub CLI signing key"
            return 1
        fi
        chmod go+r "$GHCLI_KEYRING_PATH"
    else
        log_debug "GitHub CLI signing key already present"
    fi

    local arch
    arch="$(dpkg --print-architecture)"
    local repo_entry="deb [arch=${arch} signed-by=${GHCLI_KEYRING_PATH}] https://cli.github.com/packages stable main"

    if [[ ! -f "$GHCLI_APT_SOURCE" ]] || ! grep -Fxq "$repo_entry" "$GHCLI_APT_SOURCE"; then
        echo "$repo_entry" > "$GHCLI_APT_SOURCE"
        log_info "Added GitHub CLI apt source: $GHCLI_APT_SOURCE"
    else
        log_debug "GitHub CLI apt source already configured"
    fi

    log_info "Refreshing apt cache for GitHub CLI packages"
    if ! apt update >/dev/null 2>&1; then
        log_error "Failed to refresh apt cache after adding GitHub CLI repository"
        return 1
    fi
}

ghcli_install_package() {
    if check_command "gh"; then
        log_info "GitHub CLI already installed: $(gh --version | head -n1)"
        return 0
    fi

    log_info "Installing GitHub CLI package"
    if ! install_packages "gh"; then
        log_error "Failed to install GitHub CLI package"
        return 1
    fi

    # Verify installation
    if ! check_command "gh"; then
        log_error "GitHub CLI package installed but command not found in PATH"
        return 1
    fi

    log_info "GitHub CLI installed successfully: $(gh --version | head -n1)"
}

ghcli_install_completion() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install gh bash completion to $GHCLI_COMPLETION_PATH"
        return 0
    fi

    if ! check_command "gh"; then
        log_warn "GitHub CLI not found; skipping completion installation"
        return 1
    fi

    log_info "Installing Bash completion for gh"
    mkdir -p "$(dirname "$GHCLI_COMPLETION_PATH")"
    if gh completion -s bash > "$GHCLI_COMPLETION_PATH"; then
        chmod 644 "$GHCLI_COMPLETION_PATH"
        log_success "Installed gh completion at $GHCLI_COMPLETION_PATH"
        return 0
    else
        log_warn "Failed to generate gh completion script"
        return 1
    fi
}

ghcli_attempt_authentication() {
    if [[ "${GHCLI_SKIP_AUTH:-false}" == "true" ]]; then
        log_info "Skipping GitHub CLI authentication (GHCLI_SKIP_AUTH=true)"
        return 0
    fi

    if ! check_command "gh"; then
        log_warn "GitHub CLI is not installed; skipping authentication"
        return 0
    fi

    local token
    token="$(ghcli_discover_token)"

    if [[ -z "$token" ]]; then
        log_warn "No GitHub token (GITHUB_PAT/GITHUB_TOKEN) detected; run 'gh auth login' later to authenticate"
        return 0
    fi

    log_info "Attempting to authenticate GitHub CLI using discovered token"
    ghcli_authenticate_user "root" "$token"

    if check_user_exists "$GHCLI_DEV_USERNAME"; then
        ghcli_authenticate_user "$GHCLI_DEV_USERNAME" "$token"
    fi
}

ghcli_discover_token() {
    local env_vars=("GITHUB_PAT" "GITHUB_TOKEN" "GH_TOKEN")
    for var in "${env_vars[@]}"; do
        local value="${!var:-}"
        if [[ -n "$value" ]]; then
            log_debug "Found GitHub token in environment variable: $var"
            echo "$value"
            return 0
        fi
    done

    local candidates=()
    if [[ -n "${GITHUB_TOKEN_FILE:-}" ]]; then
        candidates+=("$GITHUB_TOKEN_FILE")
    fi
    candidates+=("$SCRIPT_DIR/.env.local" "$SCRIPT_DIR/.env" "$CONFIG_DIR/.env.local")

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

        token_raw="${token_raw//\"/}"
        token_raw="${token_raw//\'/}"
        local token
        token="$(echo "$token_raw" | xargs)"

        if [[ -n "$token" ]]; then
            log_info "Loaded GitHub token from $file"
            echo "$token"
            return 0
        fi
    done

    return 0
}

ghcli_authenticate_user() {
    local target_user="$1"
    local token="$2"

    if [[ -z "$token" ]]; then
        log_warn "Empty token provided for $target_user; skipping authentication"
        return 1
    fi

    if ghcli_is_authenticated "$target_user"; then
        log_success "GitHub CLI already authenticated for user $target_user"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would authenticate GitHub CLI for $target_user"
        return 0
    fi

    local temp_token
    temp_token="$(mktemp)"
    printf '%s\n' "$token" > "$temp_token"
    chmod 600 "$temp_token"

    if [[ "$target_user" != "root" ]]; then
        local target_group
        target_group="$(id -gn "$target_user" 2>/dev/null || echo "$target_user")"
        chown "$target_user":"$target_group" "$temp_token" 2>/dev/null || true
    fi

    if ghcli_run_as "$target_user" "gh auth login --with-token < '$temp_token' >/dev/null 2>&1"; then
        log_success "Authenticated GitHub CLI for user $target_user"
        rm -f "$temp_token"
        return 0
    else
        local exit_code=$?
        log_warn "GitHub CLI authentication failed for $target_user (exit code $exit_code)"
        rm -f "$temp_token"
        return $exit_code
    fi
}

ghcli_is_authenticated() {
    local target_user="$1"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        return 1
    fi

    if ghcli_run_as "$target_user" "gh auth status >/dev/null 2>&1"; then
        return 0
    fi
    return 1
}

ghcli_run_as() {
    local target_user="$1"
    local command="$2"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run as $target_user: $command"
        return 0
    fi

    if [[ "$target_user" == "root" ]]; then
        bash -lc "$command"
    else
        su - "$target_user" -c "$command"
    fi
}

ghcli_show_summary() {
    if ! check_command "gh"; then
        log_warn "GitHub CLI not installed; no summary available"
        return 0
    fi

    log_info "GitHub CLI binary: $(command -v gh)"
    log_info "GitHub CLI version: $(gh --version | head -n1)"

    if ghcli_is_authenticated "root"; then
        log_success "Root user authenticated with GitHub CLI"
    else
        log_warn "Root user not authenticated; run 'gh auth login' as needed"
    fi

    if check_user_exists "$GHCLI_DEV_USERNAME"; then
        if ghcli_is_authenticated "$GHCLI_DEV_USERNAME"; then
            log_success "User $GHCLI_DEV_USERNAME authenticated with GitHub CLI"
        else
            log_warn "User $GHCLI_DEV_USERNAME is not authenticated; switch to the user and run 'gh auth login'"
        fi
    fi
}

