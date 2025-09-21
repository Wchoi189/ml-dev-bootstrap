#!/bin/bash

# =============================================================================
# Conda Environment Management Module
# Updates conda and configures it for development use
# =============================================================================

# Resolve repo root and source config robustly
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"
if [[ -f "$REPO_ROOT/config/defaults.conf" ]]; then
    source "$REPO_ROOT/config/defaults.conf"
fi


# Conda configuration
CONDA_PATH="${CONDA_PATH:-/opt/conda}"
DEV_HOME="${DEV_HOME:-/home/${USERNAME:-vscode-user}}"
CONDA_UPDATE="${CONDA_UPDATE:-true}"
CONDA_CHANNELS="${CONDA_CHANNELS:-conda-forge}"

# Replace the hardcoded package arrays (lines 22-38) with this:

# Parse conda packages from configuration
IFS=' ' read -ra CONDA_BASE_PACKAGES <<< "${CONDA_BASE_PACKAGES:-pip setuptools wheel jupyter ipython}"

# Data science packages (add based on profile)
IFS=' ' read -ra CONDA_DATA_PACKAGES <<< "${CONDA_DATA_PACKAGES:-numpy pandas matplotlib seaborn}"

# Development packages (optional)
IFS=' ' read -ra CONDA_DEV_PACKAGES <<< "${CONDA_DEV_PACKAGES:-black flake8 pytest mypy pre-commit}"

# Optional packages
IFS=' ' read -ra CONDA_OPTIONAL_PACKAGES <<< "${CONDA_OPTIONAL_PACKAGES:-requests beautifulsoup4}"

# Conda user preferences from configuration
CONDA_AUTO_ACTIVATE_BASE="${CONDA_AUTO_ACTIVATE_BASE:-false}"
CONDA_SHOW_CHANNEL_URLS="${CONDA_SHOW_CHANNEL_URLS:-true}"
CONDA_ALWAYS_YES="${CONDA_ALWAYS_YES:-false}"
CONDA_SOLVER="${CONDA_SOLVER:-classic}"
CONDA_DISABLE_LIBMAMBA="${CONDA_DISABLE_LIBMAMBA:-true}"


# =============================================================================
# Main Conda Setup Function
# =============================================================================
run_conda() {
    log_header "Conda Environment Setup"

    # Validate required variables
    if [[ -z "${DEV_USERNAME:-}" ]]; then
        DEV_USERNAME="${USERNAME:-vscode-user}"
        log_debug "Set DEV_USERNAME to: $DEV_USERNAME"
    fi

    if [[ -z "${DEV_GROUP:-}" ]];
then
        DEV_GROUP="${USER_GROUP:-vscode}"
        log_debug "Set DEV_GROUP to: $DEV_GROUP"
    fi

    if [[ -z "${DEV_HOME:-}" ]];
then
        DEV_HOME="/home/$DEV_USERNAME"
        log_debug "Set DEV_HOME to: $DEV_HOME"
    fi

    local total_steps=5 # Reduced from 6
    local current_step=0

    # Step 1: Detect conda installation
    ((current_step++))
    log_step $current_step $total_steps "Detecting conda installation"
    detect_conda_installation ||
{
        log_error "Conda detection failed"
        return 1
    }


    export MAMBA_ROOT_PREFIX="$CONDA_PATH"
    log_debug "Initializing micromamba shell for script execution..."
    eval "$(micromamba shell hook -s bash)" ||
{
        log_error "Failed to initialize micromamba shell"
        return 1
    }

    # Accept Terms of Service AFTER detection
    accept_conda_terms ||
{
        log_error "Failed to accept conda Terms of Service"
        return 1
    }

    # Step 2: Update conda (skipped)
    if [[ "$CONDA_UPDATE" == "true" ]];
then
        ((current_step++))
        # This step can be implemented later if needed
    else
        log_info "Skipping conda update (CONDA_UPDATE=false)"
    fi

    # Step 3
    ((current_step++))
    log_step $current_step $total_steps "Installing base packages"
    install_conda_base_packages ||
{
        log_error "Failed to install base packages"
        return 1
    }

    # Step 4: Configure conda for users
    ((current_step++))
    log_step $current_step $total_steps "Configuring conda for users"
    configure_conda_for_users ||
{
        log_error "Failed to configure conda for users"
        return 1
    }

    # Step 5: Verify conda installation
    ((current_step++))
    log_step $current_step $total_steps "Verifying conda installation"
    verify_conda_installation ||
{
        log_error "Conda verification failed"
        return 1
    }

    log_success "Conda setup completed successfully!"
show_conda_info
}

# =============================================================================
# Conda Detection Functions
# =============================================================================

# MODIFIED FUNCTION
detect_conda_installation() {
    log_info "Detecting core environment manager (micromamba)..."

    # The primary check is for the actual micromamba binary in a standard system location.
    if [[ -x "/usr/local/bin/micromamba" ]]; then
        log_success "Found micromamba executable at /usr/local/bin/micromamba."

        # Even if it exists, ensure the symlinks our script expects are in place.
        if [[ ! -d "$CONDA_PATH/bin" ]] || [[ ! -L "$CONDA_PATH/bin/conda" ]]; then
            log_info "Micromamba exists, but prefix directory isn't set up. Re-linking..."
            mkdir -p "$CONDA_PATH/bin"
            # Use -sfn to force overwrite of broken or incorrect links.
            ln -sfn /usr/local/bin/micromamba "$CONDA_PATH/bin/conda"
            ln -sfn /usr/local/bin/micromamba "$CONDA_PATH/bin/mamba"
        fi

        export DETECTED_CONDA_PATH="$CONDA_PATH"
        export CONDA_TYPE="system"
        return 0
    fi

    # If the micromamba binary is not found, proceed with a fresh installation.
    log_info "Micromamba not found. Proceeding with installation..."
    install_conda || {
        log_error "Failed to install micromamba"
        return 1
    }

    # After installation, verify it was successful.
    if [[ -x "$CONDA_PATH/bin/conda" ]]; then
        export DETECTED_CONDA_PATH="$CONDA_PATH"
        export CONDA_TYPE="system"
        log_success "Micromamba installed and verified at $CONDA_PATH"
        return 0
    else
        log_error "Micromamba installation failed verification"
        return 1
    fi
}

install_conda() {
    log_info "Installing micromamba for fast, reliable environment creation..."

    # Download micromamba binary
    local micromamba_url="https://micro.mamba.pm/api/micromamba/linux-64/latest"
    log_info "Downloading micromamba from: $micromamba_url"

    if ! wget -q -O /tmp/micromamba.tar.bz2 --user-agent="Mozilla/5.0" "$micromamba_url";
then
        log_error "Failed to download micromamba"
        return 1
    fi

    # Extract micromamba to a system-wide location
    tar -xjvf /tmp/micromamba.tar.bz2 -C /usr/local/ bin/micromamba ||
{
        log_error "Failed to extract micromamba"
        rm -f /tmp/micromamba.tar.bz2
        return 1
    }

    rm -f /tmp/micromamba.tar.bz2

    # Set up the conda prefix directory
    mkdir -p "$CONDA_PATH/bin"

    # Link micromamba so our script can find 'conda' and 'mamba'
    ln -s /usr/local/bin/micromamba "$CONDA_PATH/bin/conda"
    ln -s /usr/local/bin/micromamba "$CONDA_PATH/bin/mamba"

     log_success "Micromamba installed successfully."
    return 0
}

get_conda_command() {
    echo "$DETECTED_CONDA_PATH/bin/conda"
}

# =============================================================================
# Conda Update Functions
# =============================================================================

update_conda() {
    log_info "Updating conda to latest version..."

    local conda_cmd=$(get_conda_command)

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would update conda using: $conda_cmd"
        return 0
    fi

    # Initialize conda for this shell session
    source "$DETECTED_CONDA_PATH/etc/profile.d/conda.sh" ||
{
        log_error "Failed to initialize conda"
        return 1
    }

    # Try normal update first
    log_command "$conda_cmd update -n base -c defaults conda -y"
    if "$conda_cmd" update -n base -c defaults conda -y;
then
        log_success "Conda updated successfully"
    else
        log_warn "Normal conda update failed, trying with conflict resolution..."

        # Try with force reinstall to resolve conflicts
        log_command "$conda_cmd install -n base -c defaults conda --force-reinstall -y"
        if "$conda_cmd" install -n base -c defaults conda --force-reinstall -y;
then
            log_success "Conda updated with force reinstall"
        else
            log_warn "Conda update failed, continuing with existing version"
            local current_version=$("$conda_cmd" --version 2>/dev/null || echo "unknown")
            log_info "Current conda version: $current_version"
        fi
    fi

    # Clean conda cache regardless of update success
    log_command "$conda_cmd clean --all -y"
    "$conda_cmd" clean --all -y ||
{
        log_warn "Failed to clean conda cache"
    }

    return 0
}

# =============================================================================
# Conda Configuration Functions
# =============================================================================

set_conda_environment() {
    # Configure conda solver based on settings
    export CONDA_SOLVER="${CONDA_SOLVER:-classic}"

    # Disable libmamba if configured to avoid GLIBCXX issues
    if [[ "${CONDA_DISABLE_LIBMAMBA:-true}" == "true" ]];
then
        export CONDA_LIBMAMBA_SOLVER_NO_CHANNELS_FROM_INSTALLED=true
        log_debug "Libmamba solver disabled"
    fi

    # Plugin and telemetry settings (configurable)
    if [[ "${CONDA_NO_PLUGINS:-true}" == "true" ]];
then
        export CONDA_NO_PLUGINS=true
        log_debug "Conda plugins disabled"
    fi

    if [[ "${CONDA_REPORT_ERRORS:-false}" == "false" ]];
then
        export CONDA_REPORT_ERRORS=false
    fi

    if [[ "${ANACONDA_ANON_USAGE:-false}" == "false" ]];
then
        export ANACONDA_ANON_USAGE=false
    fi

    log_debug "Conda environment configured: solver=$CONDA_SOLVER, plugins=${CONDA_NO_PLUGINS:-false}"
}


show_conda_solver_config() {
    log_debug "Current conda solver configuration:"
    echo "  CONDA_SOLVER: ${CONDA_SOLVER}"
    echo "  CONDA_EXPERIMENTAL_SOLVER: ${CONDA_EXPERIMENTAL_SOLVER}"
    echo "  CONDA_DISABLE_LIBMAMBA: ${CONDA_DISABLE_LIBMAMBA}"

    if [[ "$CONDA_DISABLE_LIBMAMBA" == "true" ]];
then
        echo "  CONDA_LIBMAMBA_SOLVER_NO_CHANNELS_FROM_INSTALLED: true"
    fi
}
configure_conda_channels() {
    log_info "Configuring conda channels..."
    set_conda_environment

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would configure conda channels: $CONDA_CHANNELS"
        return 0
    fi

    # Convert space-separated channels to array
    IFS=' ' read -ra channels_array <<< "$CONDA_CHANNELS"

    # Add channels in reverse order
    for ((i=${#channels_array[@]}-1; i>=0; i--));
do
        local channel="${channels_array[i]}"
        log_debug "Adding conda channel: $channel"
        # Use 'conda' directly and set env var for this command
        CONDA_NO_PLUGINS=true conda config --add channels "$channel" ||
{
            log_warn "Failed to add channel: $channel"
        }
    done

    # Set channel priority
    CONDA_NO_PLUGINS=true conda config --set channel_priority strict ||
{
        log_warn "Failed to set channel priority"
    }

    # Show configured channels
    log_debug "Configured conda channels:"
    CONDA_NO_PLUGINS=true conda config --show channels |
sed 's/^/  /'

    log_success "Conda channels configured successfully"
    return 0
}

accept_conda_terms() {
    log_info "Accepting conda Terms of Service..."

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would accept conda ToS"
        return 0
    fi

    # Check if DETECTED_CONDA_PATH is set
    if [[ -z "${DETECTED_CONDA_PATH:-}" ]];
then
        log_warn "Conda path not detected yet, skipping ToS acceptance"
        return 0
    fi

    local conda_cmd=$(get_conda_command)

    # Only accept ToS if we're using Anaconda channels
    if echo "$CONDA_CHANNELS" |
grep -q "defaults\|anaconda\|repo.anaconda.com"; then
        log_info "Anaconda channels detected, accepting Terms of Service..."

        # Accept ToS for common channels
        local channels_to_accept=(
            "https://repo.anaconda.com/pkgs/main"
            "https://repo.anaconda.com/pkgs/r"
        )

        for channel in "${channels_to_accept[@]}";
do
            log_debug "Accepting ToS for channel: $channel"
            "$conda_cmd" tos accept --override-channels --channel "$channel" 2>/dev/null ||
{
                log_debug "Could not accept ToS for $channel (may not be needed)"
            }
        done
    else
        log_debug "No Anaconda channels in use, skipping ToS acceptance"
    fi

    log_success "Conda Terms of Service handling completed"
}
# =============================================================================
# Package Installation Functions
# =============================================================================
install_conda_base_packages() {
    local env_name="${CONDA_ENV_NAME:-dev_env}"
    local envs_dir="${CONDA_PATH}/envs"
    log_info "Creating new development environment: '${env_name}'"

    # --- START: EFFICIENT PERMISSIONS SETUP ---
    log_info "Preparing environment directory with efficient permissions..."
    # 1. Create the parent directory for all environments.
    mkdir -p "$envs_dir"
    # 2. Set the group ownership to your development group.
    chown "root:$DEV_GROUP" "$envs_dir"
    # 3. Set permissions: rwx for owner, rwx for group, and add the 'setgid' bit (the 's').
    #    This forces all new subdirectories to inherit the 'dev' group.
    chmod g+rwsx "$envs_dir"
    log_success "Environment directory configured to assign new files to the '$DEV_GROUP' group."
    # --- END: EFFICIENT PERMISSIONS SETUP ---


    # Build the package list based on the global profile
    local python_version="${PYTHON_VERSION:-3.10.13}"
    local core_libs="libgcc-ng libstdcxx-ng libgomp"

    local packages_to_install=(
        "python=${python_version}"
        "mamba"
        "${core_libs}"
        "${CONDA_BASE_PACKAGES[@]}"
    )

    # Add packages based on the GLOBAL_INSTALL_PROFILE
    case "${GLOBAL_INSTALL_PROFILE}" in
        "standard")
            ;;
        "full")
            ;;
    esac

    local unique_packages=($(printf "%s\n" "${packages_to_install[@]}" | sort -u))
    log_info "Creating '${env_name}' with ${#unique_packages[@]} packages..."

    micromamba create -y -p "${envs_dir}/${env_name}" \
        --channel pytorch \
        --channel nvidia \
        --channel conda-forge \
        "${unique_packages[@]}" ||
    {
        log_error "Failed to create environment '${env_name}'"
        return 1
    }

    log_success "Environment '${env_name}' created successfully."
    return 0
}

install_conda_dev_packages() {
    log_info "Installing development packages..."

    local conda_cmd=$(get_conda_command)

    local dev_packages_to_install=()
    for package in "${CONDA_DEV_PACKAGES[@]}";
do
        if ! "$conda_cmd" list -n base | grep -q "^$package ";
then
            dev_packages_to_install+=("$package")
        fi
    done

    if [[ ${#dev_packages_to_install[@]} -eq 0 ]];
then
        log_success "All development packages already installed"
        return 0
    fi

    log_info "Installing development packages: ${dev_packages_to_install[*]}"
    "$conda_cmd" install -n base -y "${dev_packages_to_install[@]}" ||
{
        log_warn "Some development packages failed to install"
        return 1
    }

    log_success "Development packages installed successfully"
    return 0
}

# =============================================================================
# User Configuration Functions
# =============================================================================

configure_conda_for_users() {
    log_info "Configuring conda for user access..."

    # Configure conda initialization for development user
    configure_conda_user_init ||
{
        log_error "Failed to configure conda user initialization"
        return 1
    }



    # Create conda configuration for user
    create_user_conda_config ||
{
        log_warn "Failed to create user conda configuration"
    }

    log_success "Conda user configuration completed"
    return 0
}

configure_conda_user_init() {
    log_debug "Configuring micromamba initialization for user..."

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would configure micromamba user initialization"
        return 0
    fi

    local bashrc_file="$DEV_HOME/.bashrc"

    # Check if initialization for the correct prefix has already been done
    if [[ -f "$bashrc_file" ]] && grep -q "micromamba shell init" "$bashrc_file" && grep -q "MAMBA_ROOT_PREFIX='$CONDA_PATH'" "$bashrc_file";
then
        log_debug "Micromamba initialization for shared prefix already present in user .bashrc"
        return 0
    fi

    # Create and set permissions for the system-wide profile directory
    # This prevents the 'Error opening for writing' message.
mkdir -p "${CONDA_PATH}/etc/profile.d"
    chown -R "${DEV_USERNAME}:${DEV_GROUP}" "${CONDA_PATH}/etc"
    chmod -R g+w "${CONDA_PATH}/etc"

    # Run micromamba's shell setup command, explicitly setting the root prefix.
log_info "Running 'micromamba shell init' for user ${DEV_USERNAME}..."
    sudo -u "$DEV_USERNAME" /usr/local/bin/micromamba shell init -s bash -r "$CONDA_PATH" ||
{
        log_warn "Failed to run micromamba shell init for user."
return 1
    }

    log_debug "Micromamba initialization configured for user .bashrc"
    return 0
}

create_user_conda_config() {
    log_debug "Creating user conda configuration..."

    local conda_config_dir="$DEV_HOME/.conda"
    local conda_config_file="$conda_config_dir/condarc"

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would create user conda config"
        return 0
    fi

    # Create conda config directory
    create_directory "$conda_config_dir" "$DEV_USERNAME:$DEV_GROUP" "755"

    # Create .condarc file if it doesn't exist

# Create .condarc file if it doesn't exist
if [[ !
-f "$conda_config_file" ]]; then
    cat > "$conda_config_file" << EOF
# Conda configuration for development user
channels:
$(for channel in $CONDA_CHANNELS; do echo "  - $channel"; done)

channel_priority: strict
auto_activate_base: $CONDA_AUTO_ACTIVATE_BASE
show_channel_urls: $CONDA_SHOW_CHANNEL_URLS
always_yes: $CONDA_ALWAYS_YES

# Solver settings (configurable)
solver: $CONDA_SOLVER

# Package cache and environment settings
pkgs_dirs:
  - $DEV_HOME/.conda/pkgs

envs_dirs:
  - $DEV_HOME/.conda/envs
  - $DETECTED_CONDA_PATH/envs

# Reporting and telemetry
report_errors: false
anaconda_upload: false

# Environment creation settings
create_default_packages:
$(for pkg in ${CONDA_BASE_PACKAGES[@]}; do echo "  - $pkg"; done)
EOF

        chown "$DEV_USERNAME:$DEV_GROUP" "$conda_config_file"
        chmod 644 "$conda_config_file"
       log_debug "User conda configuration created"
    else
        log_debug "User conda configuration already exists"
    fi

    return 0
}

# =============================================================================
# Verification Functions
# =============================================================================

verify_conda_installation() {
    log_info "Verifying conda installation..."

    # Test conda command availability
    verify_conda_command ||
{
        log_error "Conda command verification failed"
        return 1
    }

    # Test conda environment
    verify_conda_environment ||
{
        log_error "Conda environment verification failed"
        return 1
    }

    # Test user access
    verify_user_conda_access ||
{
        log_error "User conda access verification failed"
        return 1
    }

    # Test package installation
    verify_conda_packages ||
{
        log_warn "Some conda packages may not be properly installed"
    }

    log_success "Conda installation verification completed"
    return 0
}

verify_conda_command() {
    log_debug "Verifying conda command..."

    local conda_cmd=$(get_conda_command)

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would verify conda command"
        return 0
    fi

    # Test conda command
    if "$conda_cmd" --version >/dev/null 2>&1;
then
        local conda_version=$("$conda_cmd" --version)
        log_debug "Conda command working: $conda_version"
    else
        log_error "Conda command not working: $conda_cmd"
        return 1
    fi

    return 0
}

verify_conda_environment() {
    log_debug "Verifying conda environment..."

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would verify conda environment"
        return 0
    fi

    # Initialize micromamba shell
    eval "$(micromamba shell hook -s bash)" ||
{
        log_error "Failed to initialize micromamba for verification"
        return 1
    }

    # Test conda info
    if conda info >/dev/null 2>&1;
then
        log_debug "Conda environment initialized successfully"
    else
        log_error "Conda environment initialization failed"
        return 1
    fi

    return 0
}


verify_user_conda_access() {
    log_debug "Verifying user can access the shared conda environment..."
    local env_name="${CONDA_ENV_NAME:-dev_env}"

    if !
check_user_exists "$DEV_USERNAME"; then
        log_debug "User does not exist, skipping access test."
return 0
    fi

    # This is a more direct and robust test.
# It checks if the user, with the correct root prefix, can see the packages
    # in the environment we created for them.
This proves the setup is correct.
    local test_cmd="export MAMBA_ROOT_PREFIX='${CONDA_PATH}'; /usr/local/bin/micromamba list -n '${env_name}'"

    log_debug "Running verification: ${test_cmd}"
    if sudo -u "$DEV_USERNAME" bash -c "${test_cmd}" >/dev/null 2>&1;
then
        log_success "User can successfully access the '${env_name}' environment."
else
        log_error "User cannot access the shared '${env_name}' environment."
log_info "This might be a permissions issue on '${CONDA_PATH}'."
        return 1
    fi

    return 0
}

verify_conda_packages() {
    log_debug "Verifying packages in the created environment..."
    local env_name="${CONDA_ENV_NAME:-dev_env}"

    # Get a list of just the package names from the environment
    # The awk command skips the header lines and prints only the first column
    local installed_packages
    installed_packages=$(micromamba list -n "${env_name}" | awk 'NR>3 {print $1}')

    if [[ -z "$installed_packages" ]];
then
        log_warn "Could not retrieve package list from '${env_name}' for verification."
return 0 # Exit gracefully, as the main install succeeded
    fi

    local missing_packages=()
    # Check if the essential base packages exist in the list of installed packages
    for package in "${CONDA_BASE_PACKAGES[@]}";
do
        if ! echo "${installed_packages}" | grep -q -w "${package}";
then
            missing_packages+=("$package")
        fi
    done

    if [[ ${#missing_packages[@]} -gt 0 ]];
then
        log_warn "Missing key packages in '${env_name}': ${missing_packages[*]}"
        return 1
    fi

    log_success "All key packages verified successfully in '${env_name}'."
return 0
}

# =============================================================================
# Information Display Functions
# =============================================================================

show_conda_info() {
    local env_name="${CONDA_ENV_NAME:-dev_env}"
    local env_path="${CONDA_PATH}/envs/${env_name}"

    log_header "Conda Configuration Summary"

    echo "Installation:"
    echo "  Type: micromamba"
    echo "  Root Path: ${DETECTED_CONDA_PATH:-Not detected}"

    if [[ "${DRY_RUN:-false}" != "true" ]] && [[ -n "${DETECTED_CONDA_PATH:-}" ]];
then
        echo "  Version: $(micromamba --version 2>/dev/null || echo "Unknown")"

        echo ""
        echo "Created Environment:"
        micromamba env list |
sed 's/^/  /' || echo "  Unable to list environments"

        echo ""
        echo "Packages in '${env_name}' Environment (Top 10):"
        micromamba list -p "${env_path}" |
head -n 12 | sed 's/^/  /' || echo "  Unable to list packages"
        local total_packages=$(micromamba list -p "${env_path}" | wc -l)
        echo "  ... ($total_packages total packages)"
    fi

    echo ""
    echo "User Configuration:"
    echo "  Config directory: $DEV_HOME/.conda"
    echo "  User .condarc: $([ -f "$DEV_HOME/.condarc" ] && echo "✓ Exists" || echo "✗ Missing")"


log_separator

    # Show usage instructions for the created environment
    log_info "Usage Instructions:"
    echo "  • To activate your new environment, run:"
    echo "    micromamba activate ${env_name}"
    echo ""
    echo "  • To see all environments, run:"
    echo "    micromamba env list"
}

# =============================================================================
# Utility Functions
# =============================================================================

create_conda_environment() {
    local env_name="$1"
    local python_version="${2:-3.9}"
    local packages="${3:-}"

     log_info "Creating conda environment: $env_name"

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would create environment: $env_name with Python $python_version"
        return 0
    fi

    local conda_cmd=$(get_conda_command)
    source "$DETECTED_CONDA_PATH/etc/profile.d/conda.sh"

    # Check if environment already exists
    if "$conda_cmd" env list |
grep -q "^$env_name "; then
        log_warn "Environment '$env_name' already exists"
        return 0
    fi

    # Create environment
    local create_cmd="$conda_cmd create -n $env_name python=$python_version -y"
    if [[ -n "$packages" ]];
then
        create_cmd="$create_cmd $packages"
    fi

    log_command "$create_cmd"
    $create_cmd ||
{
        log_error "Failed to create conda environment: $env_name"
        return 1
    }

    log_success "Conda environment '$env_name' created successfully"
    return 0
}

cleanup_conda_cache() {
    log_info "Cleaning up conda cache and temporary files..."

    if [[ "${DRY_RUN:-false}" == "true" ]];
then
        log_info "[DRY RUN] Would clean conda cache"
        return 0
    fi

    local conda_cmd=$(get_conda_command)
    source "$DETECTED_CONDA_PATH/etc/profile.d/conda.sh"

    # Clean all conda caches
    "$conda_cmd" clean --all -y ||
{
        log_warn "Failed to clean conda cache"
        return 1
    }

    log_success "Conda cache cleaned successfully"
    return 0
}

# Export utility functions
export -f create_conda_environment cleanup_conda_cache
