#!/bin/bash
# =============================================================================
# Diagnostics Module
# Comprehensive environment diagnostics and troubleshooting
# =============================================================================

# =============================================================================
# System Information Functions
# =============================================================================

show_system_info() {
    echo "Hostname: $(hostname)"
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p 2>/dev/null || echo N/A)"
    echo "Current user: $(whoami)"
    echo "Shell: $SHELL"
    echo "Python: $(python3 --version 2>/dev/null || echo not found)"
    echo "PATH: $PATH"
}

# =============================================================================
# Comprehensive Diagnostics
# =============================================================================

run_full_diagnostics() {
    log_header "Complete Environment Diagnostics"

    echo "Running comprehensive diagnostics..."
    echo ""

    # System diagnostics
    log_info "=== System Diagnostics ==="
    show_system_info
    echo ""

    # User diagnostics
    log_info "=== User Diagnostics ==="
    if declare -f diagnose_user_issues >/dev/null; then
        diagnose_user_issues
    else
        echo "User diagnostics not available (user module not loaded)"
        # Basic user check
        if check_user_exists "$USERNAME"; then
            echo "✓ User '$USERNAME' exists"
            echo "  Home: $(getent passwd "$USERNAME" | cut -d: -f6)"
            echo "  Shell: $(getent passwd "$USERNAME" | cut -d: -f7)"
            echo "  Groups: $(groups "$USERNAME" 2>/dev/null || echo "Cannot determine")"
        else
            echo "✗ User '$USERNAME' does not exist"
        fi
    fi
    echo ""

    # Locale diagnostics
    log_info "=== Locale Diagnostics ==="
    if declare -f diagnose_locale_issues >/dev/null; then
        diagnose_locale_issues
    else
        echo "Locale diagnostics not available (locale module not loaded)"
        echo "Current locale: ${LANG:-not set}"
        echo "Available locales:"
        locale -a 2>/dev/null | grep -E "(en_US|ko_KR)" | head -5 | sed 's/^/  /' || echo "  Cannot list locales"
    fi
    echo ""

    # PATH diagnostics
    log_info "=== PATH Diagnostics ==="
    diagnose_path_issues
    echo ""

    # Git diagnostics
    log_info "=== Git Diagnostics ==="
    if check_command "git"; then
        echo "Git version: $(git --version)"
        echo "Git configuration:"
        git config --global --list 2>/dev/null | head -10 | sed 's/^/  /' || echo "  No global git config"
        echo ""

        if check_user_exists "$USERNAME"; then
            echo "User git configuration:"
            sudo -u "$USERNAME" git config --global --list 2>/dev/null | head -5 | sed 's/^/  /' || echo "  No user git config found"
        fi
    else
        echo "Git not installed"
    fi
    echo ""

    # Conda diagnostics
    log_info "=== Conda Diagnostics ==="
    if [[ -n "${DETECTED_CONDA_PATH:-}" ]]; then
        echo "Conda path: $DETECTED_CONDA_PATH"
        echo "Conda version: $($DETECTED_CONDA_PATH/bin/conda --version 2>/dev/null || echo 'Not accessible')"
        echo "Conda environments:"
        $DETECTED_CONDA_PATH/bin/conda env list 2>/dev/null | head -5 | sed 's/^/  /' || echo "  Cannot list environments"
    else
        echo "Conda not detected"
        # Try to detect conda in common locations
        local conda_locations=(
            "/opt/conda"
            "/usr/local/miniconda3"
            "/home/$USERNAME/miniconda3"
            "/home/$USERNAME/anaconda3"
        )
        echo "Checking common conda locations:"
        for loc in "${conda_locations[@]}"; do
            if [[ -d "$loc" ]]; then
                echo "  ✓ Found: $loc"
            else
                echo "  ✗ Not found: $loc"
            fi
        done
    fi
    echo ""

    # Prompt diagnostics
    log_info "=== Prompt Diagnostics ==="
    if [[ -f "/home/$USERNAME/.bash_prompt_functions" ]]; then
        echo "✓ Prompt functions file exists"
        echo "✓ Prompt configuration: ${PROMPT_STYLE:-not set}"
    else
        echo "✗ Prompt functions file missing"
    fi

    if [[ -f "/home/$USERNAME/.bashrc" ]] && grep -q "bash_prompt_functions" "/home/$USERNAME/.bashrc" 2>/dev/null; then
        echo "✓ Prompt integrated in .bashrc"
    else
        echo "✗ Prompt not integrated in .bashrc"
    fi
    echo ""

    # Environment managers diagnostics
    log_info "=== Environment Managers Diagnostics ==="
    local env_tools=("poetry" "pyenv" "pipenv" "conda" "micromamba")
    for tool in "${env_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version
            case "$tool" in
                poetry) version="$(poetry --version 2>/dev/null | cut -d' ' -f3 || echo 'unknown')" ;;
                pyenv) version="$(pyenv --version 2>/dev/null | cut -d' ' -f2 || echo 'unknown')" ;;
                pipenv) version="$(pipenv --version 2>/dev/null | cut -d' ' -f3 || echo 'unknown')" ;;
                conda) version="$(conda --version 2>/dev/null | cut -d' ' -f2 || echo 'unknown')" ;;
                micromamba) version="$(micromamba --version 2>/dev/null || echo 'unknown')" ;;
            esac
            printf "  ✓ %-12s %s\n" "$tool" "$version"
        else
            printf "  ✗ %-12s not found\n" "$tool"
        fi
    done

    log_separator
}

# =============================================================================
# PATH Diagnostics
# =============================================================================

# Verify PATH contains expected locations and tools are resolvable
diagnose_path_issues() {
    echo "Current PATH:"
    echo "  $PATH"
    echo ""

    local expected_paths=(
        "/usr/local/bin"
        "/opt/pypoetry/bin"
        "$HOME/.local/bin"
        "/opt/conda/bin"
        "/home/$USERNAME/.local/bin"
    )
    echo "Expected PATH entries:"
    for p in "${expected_paths[@]}"; do
        local in_path="no"
        if echo ":$PATH:" | grep -q ":$p:"; then in_path="yes"; fi
        local exists="no"
        [[ -d "$p" ]] && exists="yes"
        printf "  - %-25s exists=%s in_PATH=%s\n" "$p" "$exists" "$in_path"
    done
    echo ""

    echo "Tool resolution:"
    local tools=(poetry pyenv pipenv conda micromamba git python3)
    for t in "${tools[@]}"; do
        if command -v "$t" >/dev/null 2>&1; then
            local resolved
            resolved="$(command -v "$t" 2>/dev/null)"
            printf "  ✓ %-12s -> %s\n" "$t" "$resolved"
        else
            printf "  ✗ %-12s not found in PATH\n" "$t"
        fi
    done
    echo ""

    echo "Profile scripts:"
    local profiles=(
        "/etc/profile.d/ml-dev-tools.sh"
        "/etc/profile.d/poetry.sh"
        "/etc/profile.d/pyenv.sh"
        "/etc/environment"
    )
    for f in "${profiles[@]}"; do
        if [[ -f "$f" ]]; then
            printf "  ✓ %s\n" "$f"
        else
            printf "  ✗ %s (missing)\n" "$f"
        fi
    done
    echo ""

    # Poetry symlink check (common issue)
    if [[ -L "/usr/local/bin/poetry" ]]; then
        echo "Poetry shim:"
        echo "  /usr/local/bin/poetry -> $(readlink -f /usr/local/bin/poetry 2>/dev/null || echo 'unresolved')"
    fi
    echo ""

    echo "Tips: If a tool was just installed but not found, refresh your shell:"
    echo "  hash -r && exec \$SHELL -l"
}