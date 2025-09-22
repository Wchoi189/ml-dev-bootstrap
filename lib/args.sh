#!/bin/bash
# =============================================================================
# Argument Parsing Module
# Handles command line argument parsing and validation
# =============================================================================

# =============================================================================
# Argument Parsing Functions
# =============================================================================

# Parse command line arguments and set global flags
# Usage: parse_arguments "$@"
parse_arguments() {
    # Initialize option flags
    RUN_ALL=false
    SHOW_MENU_FLAG=false
    RUN_DIAGNOSTICS=false
    RUN_UPDATE=false
    CREATE_BACKUP=false
    MODULES_TO_RUN=()

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--all)
                RUN_ALL=true
                shift
                ;;
            -m|--menu)
                SHOW_MENU_FLAG=true
                shift
                ;;
            -l|--list)
                list_modules
                exit 0
                ;;
            -c|--config)
                show_config
                exit 0
                ;;
            -s|--switch-user)
                switch_to_dev_user
                exit 0
                ;;
            -d|--dry-run)
                export DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            -v|--verbose)
                export LOG_LEVEL=DEBUG
                shift
                ;;
            --verbose-output)
                export LOG_LEVEL=DEBUG
                export VERBOSE_OUTPUT=true
                shift
                ;;
            --update)
                RUN_UPDATE=true
                shift
                ;;
            --backup)
                CREATE_BACKUP=true
                shift
                ;;
            --python-version)
                if [[ -n "$2" ]]; then
                    export PYENV_PYTHON_VERSION="$2"
                    log_info "Requested Python version for pyenv: $2"
                    shift 2
                else
                    log_error "--python-version requires an argument"
                    exit 1
                fi
                ;;
            --skip-upgrade)
                export AUTO_UPGRADE=false
                log_info "Skipping system package upgrade."
                shift
                ;;
            --progress)
                export SHOW_PROGRESS=true
                shift
                ;;
            --diagnose)
                RUN_DIAGNOSTICS=true
                shift
                ;;
            -* )
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            * )
                # Check if it's a valid module
                if is_valid_module "$1"; then
                    MODULES_TO_RUN+=("$1")
                else
                    log_error "Unknown module: $1"
                    list_modules
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Legacy argument parsing for backward compatibility
# Usage: parse_legacy_arguments "$@"
parse_legacy_arguments() {
    local modules_to_run=()
    local show_menu_flag=false
    local run_all=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            -m|--menu)
                show_menu_flag=true
                shift
                ;;
            -l|--list)
                list_modules
                exit 0
                ;;
            -c|--config)
                show_config
                exit 0
                ;;
            -d|--dry-run)
                export DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            -v|--verbose)
                export LOG_LEVEL=DEBUG
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Check if it's a valid module
                if is_valid_module "$1"; then
                    modules_to_run+=("$1")
                else
                    log_error "Unknown module: $1"
                    list_modules
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Set global variables for legacy compatibility
    RUN_ALL=$run_all
    SHOW_MENU_FLAG=$show_menu_flag
    MODULES_TO_RUN=("${modules_to_run[@]}")
}

# Validate parsed arguments
validate_arguments() {
    # Basic validation - can be extended as needed
    if [[ "${RUN_ALL}" == "true" && "${SHOW_MENU_FLAG}" == "true" ]]; then
        log_warn "Both --all and --menu specified, --menu will be ignored"
    fi

    if [[ "${RUN_ALL}" == "true" && ${#MODULES_TO_RUN[@]} -gt 0 ]]; then
        log_warn "Both --all and specific modules specified, specific modules will be ignored"
    fi
}