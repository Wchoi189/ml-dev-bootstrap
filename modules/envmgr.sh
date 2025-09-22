#!/bin/bash
# =============================================================================
# Environment Manager Module (Conda, Micromamba, Pyenv, Poetry, Pipenv)
# =============================================================================


# Resolve directories relative to this script even when sourced
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"

# Robustly source config, preserving environment overrides (e.g., menu choices)
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
_PRIOR_SELECTED_ENVMGRS="${SELECTED_ENVMGRS-}"
_PRIOR_PYENV_PYTHON_VERSION="${PYENV_PYTHON_VERSION-}"
_PRIOR_PYENV_PYTHON_VERSIONS="${PYENV_PYTHON_VERSIONS-}"
_PRIOR_INSTALL_PYENV="${INSTALL_PYENV-}"
PREV_PYENV_PYTHON_VERSION="${PYENV_PYTHON_VERSION-}"
PREV_INSTALL_PYENV="${INSTALL_PYENV-}"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"
# Restore explicit env overrides (menu/CLI should win over config)
if [[ -n "${PREV_PYENV_PYTHON_VERSION}" ]]; then PYENV_PYTHON_VERSION="$PREV_PYENV_PYTHON_VERSION"; fi
if [[ -n "${PREV_INSTALL_PYENV}" ]]; then INSTALL_PYENV="$PREV_INSTALL_PYENV"; fi
[[ -n "${_PRIOR_SELECTED_ENVMGRS}" ]] && export SELECTED_ENVMGRS="${_PRIOR_SELECTED_ENVMGRS}"
[[ -n "${_PRIOR_PYENV_PYTHON_VERSION}" ]] && export PYENV_PYTHON_VERSION="${_PRIOR_PYENV_PYTHON_VERSION}"
[[ -n "${_PRIOR_PYENV_PYTHON_VERSIONS}" ]] && export PYENV_PYTHON_VERSIONS="${_PRIOR_PYENV_PYTHON_VERSIONS}"
[[ -n "${_PRIOR_INSTALL_PYENV}" ]] && export INSTALL_PYENV="${_PRIOR_INSTALL_PYENV}"

run_envmgr() {
    log_header "Python Environment Manager Setup"

    # Check context mode configuration
    local context_mode="${ENVMGR_CONTEXT_MODE:-auto}"
    case "$context_mode" in
        root-only)
            if [[ $EUID -ne 0 ]]; then
                log_info "ENVMGR_CONTEXT_MODE=root-only: Skipping installation (not running as root)"
                return 0
            fi
            ;;
        user-only)
            if [[ $EUID -eq 0 ]]; then
                log_info "ENVMGR_CONTEXT_MODE=user-only: Skipping installation (running as root)"
                return 0
            fi
            ;;
        always)
            log_info "ENVMGR_CONTEXT_MODE=always: Installing regardless of context"
            ;;
        auto|*)
            # Detect installation context
            local is_root=false
            local current_user="$(whoami)"
            if [[ $EUID -eq 0 ]]; then
                is_root=true
                log_info "Running as root - installing environment managers system-wide"
            else
                log_info "Running as user $current_user - installing environment managers for current user"
            fi
            ;;
    esac

    local managers=("uv" "conda" "micromamba" "pyenv" "poetry" "pipenv")
    local selected=( )

    # Use SELECTED_ENVMGRS env var if set (from menu), else use config
    if [[ -n "${SELECTED_ENVMGRS:-}" ]]; then
        IFS=',' read -ra selected <<< "${SELECTED_ENVMGRS,,}"
    else
        [[ "${INSTALL_UV:-no}" == "yes" ]] && selected+=("uv")
        [[ "${INSTALL_CONDA:-no}" == "yes" ]] && selected+=("conda")
        [[ "${INSTALL_MICROMAMBA:-no}" == "yes" ]] && selected+=("micromamba")
        [[ "${INSTALL_PYENV:-no}" == "yes" ]] && selected+=("pyenv")
        [[ "${INSTALL_POETRY:-no}" == "yes" ]] && selected+=("poetry")
        [[ "${INSTALL_PIPENV:-no}" == "yes" ]] && selected+=("pipenv")
    fi

    # Remove empty entries
    local filtered=()
    for m in "${selected[@]}"; do
        [[ -n "$m" ]] && filtered+=("$m")
    done
    selected=("${filtered[@]}")

    if [[ ${#selected[@]} -eq 0 ]]; then
        log_warn "No environment managers selected for installation. Check your config or menu selection."
        return 0
    fi

    log_info "Selected environment managers: ${selected[*]}"
    local installed=()
    local failed=()
    local skipped=()

    for mgr in "${selected[@]}"; do
        case "$mgr" in
            uv)
                if [[ -f "$MODULE_DIR/uv.sh" ]]; then
                    source "$MODULE_DIR/uv.sh"
                    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                        log_debug "Starting uv installation with verbose output enabled"
                    fi
                    if install_uv; then installed+=("uv"); else failed+=("uv"); fi
                else
                    log_error "uv.sh not found"
                    failed+=("uv")
                fi
                ;;
            conda)
                if [[ -f "$MODULE_DIR/conda.sh" ]]; then
                    source "$MODULE_DIR/conda.sh"
                    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                        log_debug "Starting conda installation with verbose output enabled"
                    fi
                    if run_conda; then installed+=("conda"); else failed+=("conda"); fi
                else
                    log_error "conda.sh not found"
                    failed+=("conda")
                fi
                ;;
            micromamba)
                log_warn "micromamba installer not implemented yet; skipping"
                failed+=("micromamba")
                ;;
            pyenv)
                if [[ -f "$MODULE_DIR/pyenv.sh" ]]; then
                    source "$MODULE_DIR/pyenv.sh"
                    # If user explicitly selected pyenv via menu or CLI, force-enable it
                    export INSTALL_PYENV=yes
                    # Default to quieter installs unless DEBUG logging
                    if [[ "${LOG_LEVEL:-INFO}" != "DEBUG" ]]; then
                        export PYENV_QUIET_INSTALL=yes
                    fi
                    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                        log_debug "Starting pyenv installation with verbose output enabled"
                    fi
                    install_pyenv "${PYENV_PYTHON_VERSION-}"
                    rc=$?
                    if [[ $rc -eq 0 ]]; then
                        installed+=("pyenv")
                    elif [[ $rc -eq 2 ]]; then
                        skipped+=("pyenv")
                        log_info "pyenv skipped by configuration"
                    else
                        failed+=("pyenv")
                    fi
                else
                    log_error "pyenv.sh not found"
                    failed+=("pyenv")
                fi
                ;;
            poetry)
                if [[ -f "$MODULE_DIR/poetry.sh" ]]; then
                    source "$MODULE_DIR/poetry.sh"
                    # If user explicitly selected poetry via menu or CLI, force-enable it
                    export INSTALL_POETRY=yes
                    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                        log_debug "Starting poetry installation with verbose output enabled"
                    fi
                    rc_poetry=0
                    install_poetry
                    rc_poetry=$?
                    if [[ $rc_poetry -eq 0 ]]; then
                        installed+=("poetry")
                    elif [[ $rc_poetry -eq 2 ]]; then
                        skipped+=("poetry")
                        log_info "poetry skipped by configuration"
                    else
                        failed+=("poetry")
                    fi
                else
                    log_error "poetry.sh not found"
                    failed+=("poetry")
                fi
                ;;
            pipenv)
                if [[ -f "$MODULE_DIR/pipenv.sh" ]]; then
                    source "$MODULE_DIR/pipenv.sh"
                    # If user explicitly selected pipenv via menu or CLI, force-enable it
                    export INSTALL_PIPENV=yes
                    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                        log_debug "Starting pipenv installation with verbose output enabled"
                    fi
                    if install_pipenv; then installed+=("pipenv"); else failed+=("pipenv"); fi
                else
                    log_error "pipenv.sh not found"
                    failed+=("pipenv")
                fi
                ;;
        esac
    done

    # Ensure a global PATH profile so installed tools are found by all users
    ensure_global_envmgr_paths
    # Ensure pyenv is initialized system-wide when available
    ensure_pyenv_profile

    log_blank_line
    if [[ ${#installed[@]} -gt 0 ]]; then
        log_info "Summary of installed environment managers:"
    else
        log_info "No environment managers were installed."
    fi
    for mgr in "${installed[@]}"; do
        case "$mgr" in
            conda)
                if command -v conda >/dev/null 2>&1; then
                    echo -n "  - conda: "; conda --version
                else
                    echo "  - conda: installed (version unknown)"
                fi
                ;;
            pyenv)
                if command -v pyenv >/dev/null 2>&1; then
                    echo -n "  - pyenv: "; pyenv --version
                    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                        echo "    Python versions available:"
                        pyenv versions --bare 2>/dev/null | sed 's/^/      /' || echo "      (none installed)"
                    fi
                else
                    echo "  - pyenv: installed (version unknown)"
                fi
                ;;
            poetry)
                if command -v poetry >/dev/null 2>&1; then
                    echo -n "  - poetry: "; poetry --version
                    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
                        echo "    Configuration:"
                        poetry config --list 2>/dev/null | head -5 | sed 's/^/      /' || echo "      (configuration not accessible)"
                    fi
                else
                    echo "  - poetry: installed (version unknown)"
                fi
                ;;
            pipenv)
                if command -v pipenv >/dev/null 2>&1 && pipenv --version >/dev/null 2>&1; then
                    echo -n "  - pipenv: "; pipenv --version
                else
                    echo "  - pipenv: installed (version unknown)"
                fi
                ;;
        esac
    done

    if [[ ${#skipped[@]} -gt 0 ]]; then
        log_info "Skipped: ${skipped[*]}"
    fi

    # Determine outcome
    if [[ ${#installed[@]} -gt 0 && ${#failed[@]} -eq 0 ]]; then
        log_success "Environment manager setup completed."
        return 0
    fi

    if [[ ${#installed[@]} -gt 0 && ${#failed[@]} -gt 0 ]]; then
        log_warn "Some environment managers failed: ${failed[*]}"
        return 1
    fi

    # Nothing installed (either all skipped or all failed)
    if [[ ${#selected[@]} -gt 0 ]]; then
        if [[ ${#failed[@]} -gt 0 ]]; then
            log_error "Environment manager setup failed: ${failed[*]}"
        else
            log_warn "Nothing to do: selected managers were skipped by configuration."
        fi
    else
        log_warn "No environment managers selected."
    fi
    return 1
}

# Create a global profile.d script to expose common tool paths
ensure_global_envmgr_paths() {
    local profile_script="/etc/profile.d/ml-dev-tools.sh"
    if [[ $EUID -eq 0 ]]; then
        {
            echo '# Added by ml-dev-bootstrap: ensure common dev tools on PATH'
            echo 'export PATH="/usr/local/bin:$PATH"'
            echo 'export PATH="/opt/pypoetry/bin:$PATH"'
            echo 'export PATH="/opt/conda/bin:$PATH"'
            echo 'export PATH="$HOME/.local/bin:$PATH"'
        } > "$profile_script"
        chmod 644 "$profile_script" 2>/dev/null || true
        log_info "Created global PATH profile at $profile_script"
    else
        log_warn "Not running as root - skipping global PATH profile creation"
        log_info "Consider running with sudo for system-wide PATH setup"
    fi
}

# Create a profile script to initialize pyenv for all users when present
ensure_pyenv_profile() {
    local profile_script="/etc/profile.d/pyenv.sh"
    if [[ $EUID -eq 0 ]]; then
        {
            echo '# Added by ml-dev-bootstrap: pyenv initialization'
            echo 'if [ -z "$PYENV_ROOT" ]; then'
            echo '  if [ -L /usr/local/bin/pyenv ]; then'
            echo '    _pyenv_exe="$(readlink -f /usr/local/bin/pyenv 2>/dev/null)"'
            echo '    _pyenv_root="$(dirname "$(dirname "$_pyenv_exe")")"'
            echo '    [ -d "$_pyenv_root" ] && export PYENV_ROOT="$_pyenv_root"'
            echo '  fi'
            echo 'fi'
            echo 'if [ -z "$PYENV_ROOT" ] && [ -d "$HOME/.pyenv" ]; then'
            echo '  export PYENV_ROOT="$HOME/.pyenv"'
            echo 'fi'
            echo 'if [ -n "$PYENV_ROOT" ]; then'
            echo '  export PATH="$PYENV_ROOT/bin:$PATH"'
            echo '  if command -v pyenv >/dev/null 2>&1; then'
            echo '    eval "$(pyenv init -)" 2>/dev/null || true'
            echo '  fi'
            echo 'fi'
        } > "$profile_script"
        chmod 644 "$profile_script" 2>/dev/null || true
        log_info "Created global pyenv profile at $profile_script"
    else
        log_warn "Not running as root - skipping global pyenv profile creation"
        log_info "pyenv will be initialized per-user in their shell profile"
    fi
}
