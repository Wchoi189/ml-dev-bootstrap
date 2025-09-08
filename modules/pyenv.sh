#!/bin/bash
# =============================================================================
# Pyenv Installation Module
# =============================================================================

#!/bin/bash
# Resolve directories when sourced
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"

# Load config safely but preserve runtime overrides
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
_PRIOR_PYENV_PYTHON_VERSION="${PYENV_PYTHON_VERSION-}"
_PRIOR_PYENV_PYTHON_VERSIONS="${PYENV_PYTHON_VERSIONS-}"
_PRIOR_INSTALL_PYENV="${INSTALL_PYENV-}"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"
[[ -n "${_PRIOR_PYENV_PYTHON_VERSION}" ]] && export PYENV_PYTHON_VERSION="${_PRIOR_PYENV_PYTHON_VERSION}"
[[ -n "${_PRIOR_PYENV_PYTHON_VERSIONS}" ]] && export PYENV_PYTHON_VERSIONS="${_PRIOR_PYENV_PYTHON_VERSIONS}"
[[ -n "${_PRIOR_INSTALL_PYENV}" ]] && export INSTALL_PYENV="${_PRIOR_INSTALL_PYENV}"

install_pyenv() {
    local override_versions_csv="${1:-}"
    # Respect toggle
    if [[ "${INSTALL_PYENV:-no}" != "yes" ]]; then
        log_info "[pyenv] Skipping pyenv (INSTALL_PYENV=${INSTALL_PYENV:-no})"
        return 2
    fi

    # Determine target user (prefer configured USERNAME)
    local candidate_user="${USERNAME:-}"
    local target_user target_home bashrc
    if [[ -n "$candidate_user" ]] && id "$candidate_user" &>/dev/null; then
        target_user="$candidate_user"
        target_home="/home/$candidate_user"
    elif [[ $EUID -eq 0 ]]; then
        target_user="root"
        target_home="/root"
    else
        log_error "[pyenv] No suitable user found for installation"
        return 1
    fi
    bashrc="$target_home/.bashrc"

    log_info "[pyenv] Target user: $target_user ($target_home)"

    # Check if pyenv is already installed
    if sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'command -v pyenv >/dev/null 2>&1'; then
        log_info "[pyenv] pyenv already installed for $target_user"
        # Check if requested Python versions are installed
        if [[ -n "$override_versions_csv" ]]; then
            log_debug "[pyenv] Checking requested versions: $override_versions_csv"
            IFS=',' read -ra versions_to_check <<< "$override_versions_csv"
            for ver in "${versions_to_check[@]}"; do
                ver=$(echo "$ver" | xargs)  # trim whitespace
                if sudo -H -u "$target_user" env HOME="$target_home" bash -lc "pyenv versions --bare | grep -q '^$ver$'"; then
                    log_info "[pyenv] Python $ver already installed for $target_user"
                else
                    log_info "[pyenv] Python $ver not found, will install"
                fi
            done
        fi
        return 0
    else
        log_info "[pyenv] pyenv not found for $target_user, proceeding with installation"
    fi

    # Ensure build dependencies for common Python builds
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        log_debug "[pyenv] Installing build dependencies..."
        if command -v apt >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt update -y >/dev/null 2>&1 || true
            DEBIAN_FRONTEND=noninteractive apt install -y build-essential curl git ca-certificates \
                libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
                llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev >/dev/null 2>&1 || true
        fi
    fi

    # Install pyenv if missing. Detect by binary path to avoid PATH/init issues.
    if sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'test -x "$HOME/.pyenv/bin/pyenv"'; then
        log_info "[pyenv] pyenv files present for $target_user"
    else
        log_info "[pyenv] Installing pyenv for $target_user"
        if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc 'curl -fsSL https://pyenv.run | bash'; then
            log_error "[pyenv] Installation script failed"
            return 1
        fi
    fi

    # Delegate permissions to dev group and expose binary
    local dev_group="${USER_GROUP:-dev}"
    if ! getent group "$dev_group" >/dev/null 2>&1; then
        log_info "[pyenv] Creating dev group '$dev_group'"
        groupadd "$dev_group" || true
    fi
    if [[ -d "$target_home/.pyenv" ]]; then
        chgrp -R "$dev_group" "$target_home/.pyenv" 2>/dev/null || true
        chmod -R g+rwX "$target_home/.pyenv" 2>/dev/null || true
        find "$target_home/.pyenv" -type d -exec chmod g+s {} + 2>/dev/null || true
    fi
    if [[ $EUID -eq 0 && -x "$target_home/.pyenv/bin/pyenv" ]]; then
        ln -sf "$target_home/.pyenv/bin/pyenv" /usr/local/bin/pyenv
    fi

    # Ensure pyenv init lines in bashrc
    if ! grep -q 'pyenv init' "$bashrc" 2>/dev/null; then
        {
            echo ''
            echo '# Pyenv initialization'
            echo 'export PATH="$HOME/.pyenv/bin:$PATH"'
            echo 'eval "$(pyenv init -)"'
            echo 'eval "$(pyenv virtualenv-init -)"'
        } >> "$bashrc"
    fi

    # Ensure non-interactive shells can find pyenv
    local init_snippet='export PATH="$HOME/.pyenv/bin:$PATH"; eval "$(pyenv init -)"'

    # Decide which versions to install (explicit arg > env > config)
    local versions_list
    if [[ -n "$override_versions_csv" ]]; then
        versions_list="$override_versions_csv"
    elif [[ -n "${PYENV_PYTHON_VERSION:-}" ]]; then
        versions_list="$PYENV_PYTHON_VERSION"
    else
        versions_list="${PYENV_PYTHON_VERSIONS:-}"
    fi
    log_info "[pyenv] Requested Python version(s): ${versions_list:-<none>}"

    # If none specified, don't fail—just install pyenv
    if [[ -z "$versions_list" ]]; then
        log_warn "[pyenv] No Python versions specified; installed pyenv only"
        return 0
    fi

    IFS=',' read -ra versions <<< "$versions_list"
    local any_installed=false
    for v in "${versions[@]}"; do
        local ver="$(echo "$v" | xargs)"
        [[ -z "$ver" ]] && continue
        log_info "[pyenv] Installing Python $ver for $target_user"
        # Build quietly unless in DEBUG. Capture verbose build logs to a file.
        if [[ "${PYENV_QUIET_INSTALL:-}" == "yes" ]]; then
            local build_log="/tmp/pyenv-build-$ver-$(date +%s).log"
            if sudo -H -u "$target_user" env HOME="$target_home" bash -lc "cd \"$target_home\"; $init_snippet; pyenv versions --bare | grep -qx '$ver' || pyenv install '$ver' >'$build_log' 2>&1"; then
                any_installed=true
                log_info "[pyenv] Python $ver installed (logs: $build_log)"
            else
                log_error "[pyenv] Failed to install Python $ver (see $build_log)"
                return 1
            fi
        else
            if sudo -H -u "$target_user" env HOME="$target_home" bash -lc "cd \"$target_home\"; $init_snippet; pyenv versions --bare | grep -qx '$ver' || pyenv install -v '$ver'"; then
            any_installed=true
            else
                log_error "[pyenv] Failed to install Python $ver"
                return 1
            fi
        fi
    done

    # Set first version global if provided
    local first_ver="$(echo "${versions[0]}" | xargs)"
    if [[ -n "$first_ver" ]]; then
        if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc "cd \"$target_home\"; $init_snippet; pyenv global '$first_ver'"; then
            log_error "[pyenv] Failed to set global Python to $first_ver"
            return 1
        fi
    fi

    # Verify
    if ! sudo -H -u "$target_user" env HOME="$target_home" bash -lc "cd \"$target_home\"; $init_snippet; pyenv --version >/dev/null"; then
        log_error "[pyenv] Verification failed"
        return 1
    fi
    log_success "[pyenv] Installed for $target_user"
    return 0
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    install_pyenv
fi
