#!/bin/bash

set -euo pipefail

# =============================================================================
# GitHub CLI Setup Module
# Installs and optionally authenticates GitHub CLI (gh)
# =============================================================================

# Source centralized authentication utilities
UTILS_DIR="${UTILS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../utils" && pwd)}"
# shellcheck source=../utils/auth.sh
source "$UTILS_DIR/auth.sh"

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

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install GitHub CLI package and verify commands"
        return 0
    fi
    if ! install_packages "gh"; then
        log_error "Failed to install GitHub CLI package"
        return 1
    fi

    # Give the shell a chance to pick up newly installed binaries
    log_debug "Refreshing shell command cache (hash -r)"
    hash -r 2>/dev/null || true

    # Verify installation; if gh is missing, try diagnostics + safe fallbacks
    if ! check_command "gh"; then
        log_warn "gh command not found after apt install — running diagnostics and attempting corrective actions"

        # Try a safe reinstall first
        log_info "Attempting apt reinstall of 'gh'"
        apt-get update >/dev/null 2>&1 || true
        apt-get install --reinstall -y gh >/dev/null 2>&1 || true

        # Refresh command cache again and ensure common bin directories are in PATH
        hash -r 2>/dev/null || true
        PATH_ADD="/usr/local/bin:/usr/bin:/bin"
        for p in ${PATH_ADD//:/ }; do
            case ":$PATH:" in
                *":$p:"*) ;;
                *) PATH="$p:$PATH" ;;
            esac
        done

        # Check if the package contains the binary on disk
        if dpkg -L gh >/dev/null 2>&1; then
            if dpkg -L gh | grep -E '/usr/bin/gh|/bin/gh' >/dev/null 2>&1; then
                log_info "Found gh binary in package files — refreshed PATH and hash"
                hash -r 2>/dev/null || true
            else
                log_debug "Package 'gh' installed but binary not found in known locations"
            fi
        else
            log_debug "Package 'gh' not listed by dpkg; it may not be available from apt in this environment"
        fi

        # If still no command found, attempt to download official .deb as fallback
        if ! check_command "gh"; then
            log_warn "gh still not found — attempting fallback .deb installation from GitHub releases"
            if ghcli_fallback_deb_install; then
                hash -r 2>/dev/null || true
            fi
        fi

        # Final verification
        if ! check_command "gh"; then
            log_error "GitHub CLI package installed but command not found in PATH"
            # Attempt extra diagnostics for the user
            if [[ -x "/usr/bin/gh" || -x "/bin/gh" || -x "/usr/local/bin/gh" ]]; then
                ls -l /usr/local/bin/gh /usr/bin/gh /bin/gh 2>/dev/null || true
                log_error "A gh binary exists on disk but isn't resolving on PATH — check environment or the shell login/profile"
            else
                log_error "No gh binary found on disk after both apt and fallback attempts"
            fi
            return 1
        fi

    fi

    log_info "GitHub CLI installed successfully: $(gh --version | head -n1)"
}


ghcli_fallback_deb_install() {
    # Attempt to find a release .deb for the host architecture and install it
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || echo 'amd64')"
    local candidate_url

    # Use GitHub releases API to find the browser_download_url for a matching .deb
    # We look for linux_${arch} or linux_${arch%%-*} patterns when present
    local short_arch
    short_arch="${arch%%-*}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would search GitHub releases for a .deb for arch: $arch"
        return 0
    fi

    log_info "Searching GitHub releases for gh .deb matching arch: $arch"
    candidate_url=$(curl -sL "https://api.github.com/repos/cli/cli/releases/latest" \
        | grep -E "browser_download_url[^\"]+linux_${short_arch}.*\\.deb" \
        | head -n1 | cut -d '"' -f4 || true)

    if [[ -z "$candidate_url" ]]; then
        # try more relaxed pattern
        candidate_url=$(curl -sL "https://api.github.com/repos/cli/cli/releases/latest" \
            | grep -E "browser_download_url[^\"]+linux.*\\.deb" \
            | head -n1 | cut -d '"' -f4 || true)
    fi

    if [[ -z "$candidate_url" ]]; then
        log_warn "Could not find a .deb asset URL for gh on GitHub releases (network or API restrictions)"
        return 1
    fi

    log_info "Found candidate .deb: $candidate_url"
    local tmp_deb="/tmp/ghcli-fallback.deb"

    if ! curl -fsSL "$candidate_url" -o "$tmp_deb"; then
        log_warn "Failed to download fallback .deb: $candidate_url"
        rm -f "$tmp_deb" 2>/dev/null || true
        return 1
    fi

    log_info "Installing fallback .deb package (dpkg -i)"
    if ! dpkg -i "$tmp_deb" >/dev/null 2>&1; then
        log_warn "dpkg install returned an error; attempting to fix missing dependencies"
        apt-get install -f -y >/dev/null 2>&1 || true
    fi

    rm -f "$tmp_deb" 2>/dev/null || true

    if check_command "gh"; then
        log_success "Fallback installation succeeded"
        return 0
    fi

    log_warn "Fallback .deb installation completed but 'gh' still not found"
    return 1
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
    token="$(get_github_token)"

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

# Legacy function removed - now using centralized get_github_token from utils/auth.sh
# Backward compatibility: utils/auth.sh provides ghcli_discover_token() alias

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

