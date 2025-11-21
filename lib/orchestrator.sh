#!/bin/bash
# =============================================================================
# Module Orchestrator
# Handles module execution, progress tracking, and setup coordination
# =============================================================================

# =============================================================================
# Module Execution Functions
# =============================================================================

execute_module() {
    local module="$1"
    # Backward compatibility: allow 'conda' to call 'envmgr'
    if [[ "$module" == "conda" ]]; then
        module="envmgr"
    fi
    local module_file="$MODULES_DIR/${module}.sh"
    if [[ ! -f "$module_file" ]]; then
        log_error "Module file not found: $module_file"
        return 1
    fi
    log_info "Executing module: $module"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $module_file"
        return 0
    fi
    if ! source "$module_file"; then
        log_error "Failed to source module file: $module_file"
        return 1
    fi
    if ! declare -f "run_${module}" > /dev/null; then
        log_error "Function run_${module} not found in $module_file"
        return 1
    fi
    log_debug "Starting run_${module} function..."
    if "run_${module}"; then
        log_success "Module $module completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Module $module failed with exit code $exit_code"
        return 1
    fi
}

execute_all_modules() {
    log_info "Executing all modules in order..."
    for module in "${MODULE_ORDER[@]}"; do
        [[ "$module" == "ssh" ]] && continue
        execute_module "$module" || {
            log_error "Failed to execute module: $module"
            return 1
        }
    done
    log_success "All modules completed successfully!"
}

# =============================================================================
# Progress Tracking Functions
# =============================================================================

run_all_modules_with_progress() {
    log_header "Complete Development Environment Setup"

    # Calculate actual modules to run
    local all_modules=("${MODULE_ORDER[@]}")
    local modules_to_run=()
    for module in "${all_modules[@]}"; do
        [[ "$module" == "ssh" ]] && continue
        modules_to_run+=("$module")
    done

    local total_modules=${#modules_to_run[@]}
    local completed_modules=0
    local failed_modules=()

    log_info "Starting complete setup with $total_modules modules..."
    log_separator

    for module in "${modules_to_run[@]}"; do
        ((completed_modules++))

        log_header "Module $completed_modules/$total_modules: ${module^}"
        log_info "Progress: $completed_modules/$total_modules modules"

        if execute_module "$module"; then
            log_success "Module '$module' completed successfully"
        else
            log_error "Module '$module' failed"
            failed_modules+=("$module")

            if ! confirm_action "Continue with remaining modules?" "y"; then
                log_warn "Setup cancelled by user"
                break
            fi
        fi

        log_separator
    done

    # Show final summary
    show_setup_summary $completed_modules $total_modules "${failed_modules[@]}"
}

show_setup_summary() {
    local completed="$1"
    local total="$2"
    shift 2
    local failed_modules=("$@")

    log_header "Setup Summary"

    echo "Modules processed: $completed/$total"

    if [[ ${#failed_modules[@]} -eq 0 ]]; then
        log_success "All modules completed successfully!"
        echo ""
        echo "✅ Your development environment is ready!"
        echo ""
        echo "Next steps:"
        echo "  1. Switch to development user: su - $USERNAME"
        echo "  2. Test the environment: source ~/.bashrc"
        echo "  3. Verify git configuration: git config --list"
        echo "  4. Test conda: conda --version"
        echo "  5. Check prompt: start a new shell session"
    else
        log_warn "Setup completed with ${#failed_modules[@]} failed modules"
        echo ""
        echo "Failed modules: ${failed_modules[*]}"
        echo ""
        echo "❌ Some components may not work correctly"
        echo ""
        echo "To fix issues:"
        echo "  1. Check logs for error details"
        echo "  2. Re-run failed modules individually"
        echo "  3. Use diagnostic functions: ./setup.sh --diagnose"
    fi

    echo ""
    echo "Environment Details:"
    echo "  • Username: $USERNAME"
    echo "  • User Group: $USER_GROUP"
    echo "  • Home Directory: /home/$USERNAME"
    echo "  • Git User: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    echo "  • Default Locale: ${DEFAULT_LOCALE:-en_US.UTF-8}"

    log_separator
}

# =============================================================================
# Legacy Conda Detection (for backward compatibility)
# =============================================================================

detect_conda_installation() {
    log_info "Detecting conda installation..."

    # Check multiple possible locations
    local conda_paths=(
        "/opt/conda/bin/conda"
        "/usr/bin/conda"
        "/home/$USERNAME/miniconda3/bin/conda"
        "${CONDA_PATH:-}/bin/conda"
    )

    for path in "${conda_paths[@]}"; do
        if [[ -x "$path" ]]; then
            DETECTED_CONDA_PATH=$(dirname "$(dirname "$path")")
            log_success "Found conda installation: $DETECTED_CONDA_PATH"
            return 0
        fi
    done

    log_error "No conda installation found"
    return 1
}

setup_fresh_conda() {
    log_info "Setting up fresh conda installation..."

    # Initialize conda if not already done
    if ! grep -q "conda initialize" ~/.bashrc; then
        log_info "Initializing conda..."
        "$DETECTED_CONDA_PATH/bin/conda" init bash
        source ~/.bashrc
    fi

    # Basic conda configuration
    "$DETECTED_CONDA_PATH/bin/conda" config --set auto_activate_base false
    "$DETECTED_CONDA_PATH/bin/conda" config --set channel_priority strict

    log_success "Fresh conda setup completed"
}