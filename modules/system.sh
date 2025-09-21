#!/bin/bash

# =============================================================================
# System Development Tools Module
# Installs essential development tools and updates system packages
# =============================================================================
# Add this to the beginning of modules/system.sh
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Essential packages (always installed)
declare -a ESSENTIAL_PACKAGES=(
    "curl"
    "git"
    "vim"
    "htop"
    "tree"
    "unzip"
    "zip"
    "build-essential"
)

# Standard development tools (for "standard" and "full" profiles)
declare -a STANDARD_PACKAGES=(
    "build-essential"
    "cmake"
    "pkg-config"
    "libssl-dev"
    "libffi-dev"
    "python3-dev"
)

# Full development environment (only for "full" profile)
declare -a FULL_PACKAGES=(
    "nodejs"
    "npm"
    "docker.io"
    "postgresql-client"
    "redis-tools"
    "jq"
    "aws-cli"
)

# Heavy development tools (optional)
declare -a HEAVY_PACKAGES=(
    "texlive-latex-base"
    "pandoc"
    "graphviz"
    "imagemagick"
)

declare -a BUILD_TOOLS=(
    "build-essential"
    "gcc"
    "g++"
    "make"
    "cmake"
    "pkg-config"
    "autoconf"
    "automake"
    "libtool"
)

declare -a DEVELOPMENT_TOOLS=(
    "python3-dev"
    "python3-pip"
    "python3-venv"
    "nodejs"
    "npm"
    "default-jdk"
    "golang-go"
)

declare -a SYSTEM_UTILITIES=(
    "software-properties-common"
    "apt-transport-https"
    "dirmngr"
    "gpg-agent"
    "sudo"
    "systemd"
    "systemctl"
)

# =============================================================================
# Main System Setup Function
# =============================================================================


run_system() {
    log_header "System Development Tools Setup"

    # Step 1: Update package cache
    log_info "Step 1/3: Updating system packages"
    update_system_packages || {
        log_error "Failed to update system packages"
        return 1
    }

    # Step 2: Install packages based on profile
    log_info "Step 2/3: Installing packages (profile: ${INSTALL_PROFILE:-minimal})"
    install_packages_by_profile || {
        log_error "Failed to install packages"
        return 1
    }

    # Step 2b: Install pyenv build dependencies
    log_info "Installing pyenv build dependencies (for Python compilation)..."
    apt-get update
    apt-get install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
        xz-utils tk-dev libffi-dev liblzma-dev make gcc
    log_info "pyenv build dependencies installed."

    # Step 3: Basic system configuration
    log_info "Step 3/3: Basic system configuration"
    configure_basic_system || {
        log_error "Failed to configure system"
        return 1
    }

    log_success "System setup completed successfully!"
    show_installed_packages
}

configure_basic_system() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure basic system settings"
        return 0
    fi

    # Just basic cleanup
    apt autoremove -y >/dev/null 2>&1 || true
    apt autoclean >/dev/null 2>&1 || true

    log_debug "Basic system configuration completed"
}

show_installed_packages() {
    log_info "Verification - checking key tools:"
    local tools=("curl" "git" "vim")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "  ✅ $tool: installed"
        else
            echo "  ❌ $tool: missing"
        fi
    done
}

# =============================================================================
# Package Installation Functions
# =============================================================================

update_system_packages() {
    log_info "Updating package cache and upgrading existing packages..."

    # Update apt sources to Kakao (Korea) mirror
    if [[ -f /etc/apt/sources.list ]]; then
        log_info "Backing up current apt sources.list..."
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        log_info "Updating apt sources to use Kakao (Korea) mirrors..."
        sed -i 's|http://[a-zA-Z0-9.\-]*/ubuntu|http://mirror.kakao.com/ubuntu|g' /etc/apt/sources.list
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: apt update && apt upgrade"
        return 0
    fi

    # Update package cache
    apt update || {
        log_error "Failed to update package cache"
        return 1
    }

    # Upgrade existing packages automatically
    if [[ "${AUTO_UPGRADE:-true}" == "true" ]]; then
        DEBIAN_FRONTEND=noninteractive apt upgrade -y || {
            log_warn "Some packages failed to upgrade, continuing..."
        }
    else
        log_info "Skipping package upgrade (AUTO_UPGRADE=false)"
    fi

    return 0
}

install_packages_by_profile() {
    local packages_to_install=()
    local profile="${INSTALL_PROFILE:-minimal}"

    # Always install essential packages
    packages_to_install+=("${ESSENTIAL_PACKAGES[@]}")
    log_info "Installing essential packages (${#ESSENTIAL_PACKAGES[@]} packages)"

    case "$profile" in
        "minimal")
            log_info "Using minimal installation profile"
            ;;
        "standard")
            log_info "Using standard installation profile"
            packages_to_install+=("${STANDARD_PACKAGES[@]}")
            ;;
        "full")
            log_info "Using full installation profile"
            packages_to_install+=("${STANDARD_PACKAGES[@]}")
            packages_to_install+=("${FULL_PACKAGES[@]}")
            ;;
        *)
            log_warn "Unknown profile: $profile, using minimal"
            ;;
    esac

    # Show what will be installed
    log_info "Total packages to install: ${#packages_to_install[@]}"
    log_debug "Packages: ${packages_to_install[*]}"

    # Install the packages
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        install_packages "${packages_to_install[@]}"
    fi
}

install_packages() {
    local packages=("$@")
    log_info "Installing ${#packages[@]} packages..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install: ${packages[*]}"
        return 0
    fi

    DEBIAN_FRONTEND=noninteractive apt install -y "${packages[@]}" || {
        log_error "Package installation failed"
        return 1
    }

    log_success "Packages installed successfully"
}

# Utility functions
check_command() {
    command -v "$1" >/dev/null 2>&1
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        return 0
    else
        return 1
    fi
}
# =============================================================================
# Verification Functions
# =============================================================================

verify_essential_packages() {
    log_debug "Verifying essential packages installation..."

    local critical_commands=("curl" "wget" "git" "vim")
    local failed_commands=()

    for cmd in "${critical_commands[@]}"; do
        if ! check_command "$cmd"; then
            failed_commands+=("$cmd")
        fi
    done

    if [[ ${#failed_commands[@]} -gt 0 ]]; then
        log_error "Critical commands not available: ${failed_commands[*]}"
        return 1
    fi

    log_debug "Essential packages verification passed"
    return 0
}

verify_build_environment() {
    log_debug "Verifying build environment..."

    local build_commands=("gcc" "g++" "make" "cmake")
    local failed_commands=()

    for cmd in "${build_commands[@]}"; do
        if ! check_command "$cmd"; then
            failed_commands+=("$cmd")
        fi
    done

    if [[ ${#failed_commands[@]} -gt 0 ]]; then
        log_warn "Some build tools not available: ${failed_commands[*]}"
        return 1
    fi

    # Test basic compilation
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        local test_file="/tmp/test_build_$$"
        echo 'int main(){return 0;}' > "${test_file}.c"

        if gcc "${test_file}.c" -o "$test_file" 2>/dev/null; then
            log_debug "Build environment test compilation successful"
            rm -f "$test_file" "${test_file}.c"
        else
            log_warn "Build environment test compilation failed"
            rm -f "$test_file" "${test_file}.c"
            return 1
        fi
    fi

    log_debug "Build environment verification passed"
    return 0
}

configure_development_tools() {
    log_debug "Configuring development tools..."

    # Configure Python pip
    if check_command "pip3"; then
        log_debug "Upgrading pip to latest version"
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            pip3 install --upgrade pip 2>/dev/null || log_warn "Failed to upgrade pip"
        fi
    fi

    # Configure Node.js npm
    if check_command "npm"; then
        log_debug "Configuring npm"
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            npm config set fund false 2>/dev/null || log_warn "Failed to configure npm"
        fi
    fi

    return 0
}

# =============================================================================
# System Configuration Functions
# =============================================================================

configure_system_settings() {
    log_info "Configuring system settings..."

    # Configure timezone if specified
    if [[ -n "${TIMEZONE:-}" ]]; then
        configure_timezone "$TIMEZONE"
    fi

    # Configure system limits
    configure_system_limits

    # Configure sudo settings
    configure_sudo_settings

    # Clean up package cache
    cleanup_package_cache

    return 0
}

configure_timezone() {
    local timezone="$1"

    log_info "Setting timezone to: $timezone"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would set timezone to: $timezone"
        return 0
    fi

    if [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
        ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
        echo "$timezone" > /etc/timezone
        log_success "Timezone set to: $timezone"
    else
        log_error "Invalid timezone: $timezone"
        return 1
    fi
}

configure_system_limits() {
    log_debug "Configuring system limits..."

    local limits_file="/etc/security/limits.conf"
    local limits_config="
# Added by setup-utility
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure system limits in $limits_file"
        return 0
    fi

    if [[ -f "$limits_file" ]] && ! grep -q "Added by setup-utility" "$limits_file"; then
        backup_file "$limits_file"
        echo "$limits_config" >> "$limits_file"
        log_debug "System limits configured"
    else
        log_debug "System limits already configured or file not found"
    fi
}

configure_sudo_settings() {
    log_debug "Configuring sudo settings..."

    local sudoers_file="/etc/sudoers.d/setup-utility"
    local sudo_config="
# Added by setup-utility
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

# Allow passwordless sudo for development group (if exists)
%${USER_GROUP:-vscode}   ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/systemctl
"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure sudo settings"
        return 0
    fi

    if [[ ! -f "$sudoers_file" ]]; then
        echo "$sudo_config" > "$sudoers_file"
        chmod 440 "$sudoers_file"

        # Validate sudoers file
        if visudo -c -f "$sudoers_file" >/dev/null 2>&1; then
            log_debug "Sudo configuration added successfully"
        else
            log_error "Invalid sudo configuration, removing file"
            rm -f "$sudoers_file"
            return 1
        fi
    else
        log_debug "Sudo configuration already exists"
    fi
}

cleanup_package_cache() {
    log_debug "Cleaning up package cache..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would clean package cache"
        return 0
    fi

    apt autoremove -y >/dev/null 2>&1 || log_warn "Failed to autoremove packages"
    apt autoclean >/dev/null 2>&1 || log_warn "Failed to clean package cache"

    log_debug "Package cache cleaned"
}

# =============================================================================
# Information Display Functions
# =============================================================================

show_system_info() {
    log_header "System Information"

    echo "Operating System:"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "  Name: $PRETTY_NAME"
        echo "  Version: $VERSION"
        echo "  ID: $ID"
    fi

    echo ""
    echo "System Resources:"
    echo "  CPU Cores: $(nproc)"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  Disk Space: $(df -h / | awk 'NR==2 {print $4 " available of " $2}')"

    echo ""
    echo "Installed Development Tools:"
    local tools=("gcc" "python3" "node" "git" "vim")
    for tool in "${tools[@]}"; do
        if check_command "$tool"; then
            local version=$($tool --version 2>/dev/null | head -n1 | cut -d' ' -f1-3)
            echo "  $tool: $version"
        else
            echo "  $tool: Not installed"
        fi
    done

    log_separator
}