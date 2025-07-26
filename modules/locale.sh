#!/bin/bash

# =============================================================================
# Locale Configuration Module
# Sets up system locales with proper English and Korean support
# =============================================================================

# Default locale configuration
DEFAULT_LOCALE="${DEFAULT_LOCALE:-en_US.UTF-8}"
ADDITIONAL_LOCALES="${ADDITIONAL_LOCALES:-ko_KR.UTF-8}"

# Locale packages
# declare -a LOCALE_PACKAGES=(
#     "locales"
#     "language-pack-en"
#     "language-pack-en-base"
#     "language-pack-ko"
#     "language-pack-ko-base"
# )
declare -a LOCALE_PACKAGES=(
    "locales"
)

# Font packages for Korean support
declare -a FONT_PACKAGES=(
    "fontconfig"  # Add this for fc-cache command
    "fonts-nanum"
    "fonts-nanum-coding"
    "fonts-nanum-extra"
    "fonts-dejavu-core"
    "fonts-liberation"
)

# Optional: Only install Korean language pack if needed
declare -a OPTIONAL_PACKAGES=(
    "language-pack-ko"
    "language-pack-ko-base"
)
# =============================================================================
# Main Locale Setup Function
# =============================================================================

run_locale() {
    log_header "Locale Configuration Setup"
    
    local total_steps=6
    local current_step=0
    
    # Step 1: Install locale packages
    ((current_step++))
    log_step $current_step $total_steps "Installing locale packages"
    install_locale_packages || {
        log_error "Failed to install locale packages"
        return 1
    }
    
    # Step 2: Install font packages
    ((current_step++))
    log_step $current_step $total_steps "Installing font packages"
    install_font_packages || {
        log_error "Failed to install font packages"
        return 1
    }
    
    # Step 3: Generate locales
    ((current_step++))
    log_step $current_step $total_steps "Generating system locales"
    generate_minimal_locales || {  # Changed from generate_locales
        log_error "Failed to generate locales"
        return 1
    }
    
    # Step 4: Set default locale
    ((current_step++))
    log_step $current_step $total_steps "Setting default locale"
    set_default_locale || {
        log_error "Failed to set default locale"
        return 1
    }
    
    # Step 5: Configure environment variables
    ((current_step++))
    log_step $current_step $total_steps "Configuring locale environment"
    configure_locale_environment || {
        log_error "Failed to configure locale environment"
        return 1
    }
    
    # Step 6: Verify locale configuration
    ((current_step++))
    log_step $current_step $total_steps "Verifying locale configuration"
    verify_locale_configuration || {
        log_error "Locale verification failed"
        return 1
    }
    
    log_success "Locale configuration completed successfully!"
    show_locale_info
}

# =============================================================================
# Package Installation Functions
# =============================================================================

install_locale_packages() {
    log_info "Installing locale support packages..."
    
    # Set temporary locale to avoid issues during installation
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
    
    local missing_packages=()
    for package in "${LOCALE_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_success "All locale packages already installed"
        return 0
    fi
    
    install_packages "${missing_packages[@]}" || {
        log_error "Failed to install locale packages"
        return 1
    }
    
    log_success "Locale packages installed successfully"
    return 0
}

install_font_packages() {
    log_info "Installing font packages for multilingual support..."
    
    local missing_packages=()
    for package in "${FONT_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_success "All font packages already installed"
        return 0
    fi
    
    install_packages "${missing_packages[@]}" || {
        log_error "Failed to install font packages"
        return 1
    }
    
    # Update font cache
    if check_command "fc-cache"; then
        log_debug "Updating font cache..."
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            fc-cache -fv >/dev/null 2>&1 || log_warn "Failed to update font cache"
        fi
    fi
    
    log_success "Font packages installed successfully"
    return 0
}

# =============================================================================
# Locale Generation Functions
# =============================================================================
# Add this new function before generate_locales:

clean_existing_locales() {
    log_info "Cleaning existing locale configurations..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would clean existing locales"
        return 0
    fi
    
    # Stop any running locale processes
    pkill -f locale-gen 2>/dev/null || true
    
    # Clear locale cache
    rm -f /var/lib/locales/supported.d/* 2>/dev/null || true
    rm -f /usr/lib/locale/locale-archive 2>/dev/null || true
    
    log_debug "Existing locale configurations cleaned"
}


generate_locales() {
    log_info "Generating system locales..."
    
    # Clean existing configurations first
    clean_existing_locales || {
        log_warn "Failed to clean existing locales, continuing..."
    }
        
    # Prepare locale list
    local locales_to_generate=("$DEFAULT_LOCALE")
    
    # Add additional locales
    if [[ -n "$ADDITIONAL_LOCALES" ]]; then
        IFS=' ' read -ra additional_array <<< "$ADDITIONAL_LOCALES"
        locales_to_generate+=("${additional_array[@]}")
    fi
    
    # Remove duplicates
    local unique_locales=($(printf "%s\n" "${locales_to_generate[@]}" | sort -u))
    
    log_info "Locales to generate: ${unique_locales[*]}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would generate locales: ${unique_locales[*]}"
        return 0
    fi
    
    # Configure locale.gen file
    configure_locale_gen "${unique_locales[@]}" || {
        log_error "Failed to configure locale.gen"
        return 1
    }
    
    # Generate locales
    log_command "locale-gen"
    locale-gen || {
        log_error "Failed to generate locales"
        return 1
    }
    
    log_success "Locales generated successfully"
    return 0
}

configure_locale_gen() {
    local locales=("$@")
    local locale_gen_file="/etc/locale.gen"
    
    log_debug "Configuring $locale_gen_file for specific locales only"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure locale.gen with: ${locales[*]}"
        return 0
    fi
    
    # Backup original file
    backup_file "$locale_gen_file"
    
    # AGGRESSIVE CLEANUP - Remove all existing locale configurations
    # Stop any running locale generation
    pkill -f locale-gen 2>/dev/null || true
    
    # Clean slate approach
    cat > "$locale_gen_file" << EOF
# Locale configuration generated by setup-utility
# This file has been completely regenerated to avoid conflicts

EOF
    
    # Add ONLY the requested locales
    for locale in "${locales[@]}"; do
        log_debug "Adding locale: $locale"
        echo "$locale UTF-8" >> "$locale_gen_file"
    done
    
    # Clear any cached locale data
    rm -f /var/lib/locales/supported.d/* 2>/dev/null || true
    
    log_debug "Locale.gen configured with only: ${locales[*]}"
    return 0
}

generate_minimal_locales() {
    log_info "Generating minimal locales: en_US.UTF-8 ko_KR.UTF-8"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would generate minimal locales"
        return 0
    fi
    
    # Complete cleanup - remove ALL existing locale data
    rm -rf /var/lib/locales/supported.d/* 2>/dev/null || true
    rm -f /usr/lib/locale/locale-archive 2>/dev/null || true
    
    # Create minimal locale.gen with ONLY our 2 locales
    cat > /etc/locale.gen << 'EOF'
# Minimal locale configuration - only English and Korean
en_US.UTF-8 UTF-8
ko_KR.UTF-8 UTF-8
EOF
    
    # Generate ONLY the locales in the file (use specific locale names)
    log_info "Generating only specified locales..."
    locale-gen en_US.UTF-8 ko_KR.UTF-8 || {
        log_error "Failed to generate specific locales"
        return 1
    }
    
    log_success "Successfully generated 2 locales: en_US.UTF-8, ko_KR.UTF-8"
}

# =============================================================================
# Default Locale Configuration
# =============================================================================

set_default_locale() {
    log_info "Setting default system locale to: $DEFAULT_LOCALE"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would set default locale to: $DEFAULT_LOCALE"
        return 0
    fi
    
    # Update system locale
    log_command "update-locale LANG=$DEFAULT_LOCALE"
    update-locale LANG="$DEFAULT_LOCALE" || {
        log_error "Failed to update system locale"
        return 1
    }
    
    # Configure /etc/default/locale
    configure_default_locale_file || {
        log_error "Failed to configure default locale file"
        return 1
    }
    
    log_success "Default locale set successfully"
    return 0
}

configure_default_locale_file() {
    local locale_file="/etc/default/locale"
    
    log_debug "Configuring $locale_file"
    
    # Backup original file
    backup_file "$locale_file"
    
    # Create new locale configuration
    cat > "$locale_file" << EOF
# Locale configuration generated by setup-utility
LANG="$DEFAULT_LOCALE"
LANGUAGE="en_US:ko_KR"
LC_CTYPE="$DEFAULT_LOCALE"
LC_NUMERIC="$DEFAULT_LOCALE"
LC_TIME="$DEFAULT_LOCALE"
LC_COLLATE="$DEFAULT_LOCALE"
LC_MONETARY="$DEFAULT_LOCALE"
LC_MESSAGES="$DEFAULT_LOCALE"
LC_PAPER="$DEFAULT_LOCALE"
LC_NAME="$DEFAULT_LOCALE"
LC_ADDRESS="$DEFAULT_LOCALE"
LC_TELEPHONE="$DEFAULT_LOCALE"
LC_MEASUREMENT="$DEFAULT_LOCALE"
LC_IDENTIFICATION="$DEFAULT_LOCALE"
LC_ALL=
EOF
    
    log_debug "Default locale file configured"
    return 0
}

# =============================================================================
# Environment Configuration
# =============================================================================

configure_locale_environment() {
    log_info "Configuring locale environment variables..."
    
    # Configure system-wide environment
    configure_system_environment || {
        log_error "Failed to configure system environment"
        return 1
    }
    
    # Configure shell profiles
    configure_shell_profiles || {
        log_error "Failed to configure shell profiles"
        return 1
    }
    
    log_success "Locale environment configured successfully"
    return 0
}

configure_system_environment() {
    local env_file="/etc/environment"
    
    log_debug "Configuring system environment in $env_file"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure system environment"
        return 0
    fi
    
    # Backup original file
    backup_file "$env_file"
    
    # Remove existing locale entries added by setup-utility
    if [[ -f "$env_file" ]]; then
        sed -i '/# Added by setup-utility - locale/,/# End setup-utility - locale/d' "$env_file"
    fi
    
    # Add new locale configuration
    cat >> "$env_file" << EOF

# Added by setup-utility - locale
LANG="$DEFAULT_LOCALE"
LANGUAGE="en_US:ko_KR"
LC_ALL="$DEFAULT_LOCALE"
# End setup-utility - locale
EOF
    
    log_debug "System environment configured"
    return 0
}

configure_shell_profiles() {
    local profile_files=("/etc/bash.bashrc" "/etc/profile")
    
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]]; then
            configure_profile_file "$profile_file"
        fi
    done
    
    return 0
}

configure_profile_file() {
    local profile_file="$1"
    
    log_debug "Configuring locale in $profile_file"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure $profile_file"
        return 0
    fi
    
    # Check if already configured
    if grep -q "setup-utility - locale" "$profile_file"; then
        log_debug "Locale already configured in $profile_file"
        return 0
    fi
    
    # Backup original file
    backup_file "$profile_file"
    
    # Add locale configuration
    cat >> "$profile_file" << EOF

# Added by setup-utility - locale
export LANG="$DEFAULT_LOCALE"
export LANGUAGE="en_US:ko_KR"
export LC_ALL="$DEFAULT_LOCALE"
EOF
    
    log_debug "Profile file $profile_file configured"
    return 0
}

# =============================================================================
# Verification Functions
# =============================================================================

verify_locale_configuration() {
    log_info "Verifying locale configuration..."
    
    # Check if locales were generated
    verify_generated_locales || {
        log_error "Generated locales verification failed"
        return 1
    }
    
    # Check default locale setting
    verify_default_locale || {
        log_error "Default locale verification failed"
        return 1
    }
    
    # Check environment configuration
    verify_environment_config || {
        log_warn "Environment configuration verification had issues"
    }
    
    log_success "Locale configuration verification completed"
    return 0
}

verify_generated_locales() {
    log_debug "Verifying generated locales..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would verify generated locales"
        return 0
    fi
    
    local required_locales=("$DEFAULT_LOCALE")
    if [[ -n "$ADDITIONAL_LOCALES" ]]; then
        IFS=' ' read -ra additional_array <<< "$ADDITIONAL_LOCALES"
        required_locales+=("${additional_array[@]}")
    fi
    
    local missing_locales=()
    for locale in "${required_locales[@]}"; do
        if ! locale -a | grep -q "^${locale%.*}"; then
            missing_locales+=("$locale")
        fi
    done
    
    if [[ ${#missing_locales[@]} -gt 0 ]]; then
        log_error "Missing locales: ${missing_locales[*]}"
        return 1
    fi
    
    log_debug "All required locales are available"
    return 0
}

verify_default_locale() {
    log_debug "Verifying default locale setting..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would verify default locale"
        return 0
    fi
    
    # Check current locale setting
    local current_lang=$(locale | grep "^LANG=" | cut -d'=' -f2 | tr -d '"')
    
    if [[ "$current_lang" != "$DEFAULT_LOCALE" ]]; then
        log_warn "Current LANG ($current_lang) differs from expected ($DEFAULT_LOCALE)"
        log_warn "Locale changes will take effect after logout/restart"
    else
        log_debug "Default locale is correctly set"
    fi
    
    return 0
}

verify_environment_config() {
    log_debug "Verifying environment configuration..."
    
    local config_files=("/etc/default/locale" "/etc/environment")
    local missing_configs=()
    
    for config_file in "${config_files[@]}"; do
        if [[ ! -f "$config_file" ]]; then
            missing_configs+=("$config_file")
        elif ! grep -q "$DEFAULT_LOCALE" "$config_file"; then
            missing_configs+=("$config_file (missing locale)")
        fi
    done
    
    if [[ ${#missing_configs[@]} -gt 0 ]]; then
        log_warn "Environment configuration issues: ${missing_configs[*]}"
        return 1
    fi
    
    log_debug "Environment configuration verified"
    return 0
}

# =============================================================================
# Information Display Functions
# =============================================================================

show_locale_info() {
    log_header "Locale Configuration Summary"
    
    echo "Default Locale: $DEFAULT_LOCALE"
    echo "Additional Locales: ${ADDITIONAL_LOCALES:-None}"
    echo ""
    
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        echo "Available Locales:"
        locale -a | grep -E "(en_US|ko_KR)" | sed 's/^/  /' || echo "  Unable to list locales"
        
        echo ""
        echo "Current Locale Settings:"
        locale | sed 's/^/  /' || echo "  Unable to show current locale"
        
        echo ""
        echo "Installed Font Packages:"
        for package in "${FONT_PACKAGES[@]}"; do
            if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                echo "  ✓ $package"
            else
                echo "  ✗ $package"
            fi
        done
    else
        echo "[DRY RUN] Locale information would be displayed here"
    fi
    
    echo ""
    echo "Configuration Files:"
    local config_files=("/etc/default/locale" "/etc/environment" "/etc/locale.gen")
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (missing)"
        fi
    done
    
    log_separator
    
    # Show important notes
    log_info "Important Notes:"
    echo "  • Locale changes require logout/restart to take full effect"
    echo "  • Korean fonts are installed for proper character display"
    echo "  • Environment variables are configured system-wide"
    echo "  • Use 'locale' command to verify current settings"
}

# =============================================================================
# Utility Functions
# =============================================================================

test_locale_support() {
    local locale_to_test="${1:-$DEFAULT_LOCALE}"
    
    log_info "Testing locale support for: $locale_to_test"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would test locale support"
        return 0
    fi
    
    # Test if locale can be set
    if LC_ALL="$locale_to_test" locale >/dev/null 2>&1; then
        log_success "Locale $locale_to_test is working correctly"
        return 0
    else
        log_error "Locale $locale_to_test is not working properly"
        return 1
    fi
}

reset_locale_to_default() {
    log_warn "Resetting locale to system default..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would reset locale to default"
        return 0
    fi
    
    # Reset to C.UTF-8 as fallback
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
    
    log_info "Locale temporarily reset to C.UTF-8"
    log_info "Run the locale module again to reconfigure"
}

# =============================================================================
# Troubleshooting Functions
# =============================================================================

diagnose_locale_issues() {
    log_header "Locale Diagnostics"
    
    echo "System Information:"
    echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
    echo "  Kernel: $(uname -r)"
    echo ""
    
    echo "Locale Packages:"
    for package in "${LOCALE_PACKAGES[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            echo "  ✓ $package (installed)"
        else
            echo "  ✗ $package (missing)"
        fi
    done
    
    echo ""
    echo "Configuration Files Status:"
    local files=("/etc/locale.gen" "/etc/default/locale" "/etc/environment")
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "  ✓ $file (exists)"
            if grep -q "$DEFAULT_LOCALE" "$file" 2>/dev/null; then
                echo "    - Contains default locale"
            else
                echo "    - Missing default locale configuration"
            fi
        else
            echo "  ✗ $file (missing)"
        fi
    done
    
    echo ""
    echo "Available Locales:"
    if command -v locale >/dev/null 2>&1; then
        locale -a | head -10 | sed 's/^/  /'
        local total_locales=$(locale -a | wc -l)
        echo "  ... ($total_locales total locales available)"
    else
        echo "  locale command not available"
    fi
    
    log_separator
}

# Export functions for external use
export -f test_locale_support reset_locale_to_default diagnose_locale_issues