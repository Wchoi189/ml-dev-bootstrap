#!/bin/bash
# =============================================================================
# Platform Detection Module
# Detects operating system and distribution for platform-aware logic
# =============================================================================
# This module provides functions to detect the current operating system
# and Linux distribution. This enables platform-aware behavior throughout
# the setup scripts.
#
# Exported Variables:
#   OS_TYPE         - Operating system type (linux, macos, unknown)
#   DISTRO_NAME     - Distribution name (ubuntu, debian, fedora, etc.)
#   DISTRO_VERSION  - Distribution version
#   DISTRO_CODENAME - Distribution codename (if available)
#   ARCH            - System architecture (x86_64, arm64, etc.)
# =============================================================================

set -euo pipefail

# =============================================================================
# OS Detection Functions
# =============================================================================

# Detect the operating system type
detect_os() {
    local os_type="unknown"

    case "$(uname -s)" in
        Linux*)
            os_type="linux"
            ;;
        Darwin*)
            os_type="macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            os_type="windows"
            ;;
        *)
            os_type="unknown"
            ;;
    esac

    echo "$os_type"
}

# Detect Linux distribution
detect_distro() {
    local distro_name="unknown"

    # Check for /etc/os-release (modern standard)
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        distro_name="${ID:-unknown}"
    # Fallback to lsb_release if available
    elif command -v lsb_release &>/dev/null; then
        distro_name="$(lsb_release -si | tr '[:upper:]' '[:lower:]')"
    # Check for distribution-specific files
    elif [[ -f /etc/debian_version ]]; then
        distro_name="debian"
    elif [[ -f /etc/redhat-release ]]; then
        distro_name="rhel"
    elif [[ -f /etc/fedora-release ]]; then
        distro_name="fedora"
    elif [[ -f /etc/arch-release ]]; then
        distro_name="arch"
    fi

    echo "$distro_name"
}

# Detect Linux distribution version
detect_distro_version() {
    local distro_version="unknown"

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        distro_version="${VERSION_ID:-unknown}"
    elif command -v lsb_release &>/dev/null; then
        distro_version="$(lsb_release -sr)"
    elif [[ -f /etc/debian_version ]]; then
        distro_version="$(cat /etc/debian_version)"
    fi

    echo "$distro_version"
}

# Detect Linux distribution codename
detect_distro_codename() {
    local distro_codename="unknown"

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        distro_codename="${VERSION_CODENAME:-unknown}"
    elif command -v lsb_release &>/dev/null; then
        distro_codename="$(lsb_release -sc)"
    fi

    echo "$distro_codename"
}

# Detect system architecture
detect_arch() {
    local arch="$(uname -m)"

    # Normalize architecture names
    case "$arch" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l)
            arch="armv7"
            ;;
        i386|i686)
            arch="i386"
            ;;
    esac

    echo "$arch"
}

# =============================================================================
# Platform Feature Detection
# =============================================================================

# Check if running on WSL (Windows Subsystem for Linux)
is_wsl() {
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        return 0
    fi
    return 1
}

# Check if running in a container (Docker, LXC, etc.)
is_container() {
    if [[ -f /.dockerenv ]]; then
        return 0
    fi
    if grep -qa container=lxc /proc/1/environ 2>/dev/null; then
        return 0
    fi
    if [[ -f /run/systemd/container ]]; then
        return 0
    fi
    return 1
}

# Check if systemd is available
has_systemd() {
    command -v systemctl &>/dev/null && systemctl --version &>/dev/null
}

# =============================================================================
# Package Manager Detection
# =============================================================================

# Detect available package manager
detect_package_manager() {
    local pkg_mgr="unknown"

    if command -v apt-get &>/dev/null; then
        pkg_mgr="apt"
    elif command -v dnf &>/dev/null; then
        pkg_mgr="dnf"
    elif command -v yum &>/dev/null; then
        pkg_mgr="yum"
    elif command -v pacman &>/dev/null; then
        pkg_mgr="pacman"
    elif command -v zypper &>/dev/null; then
        pkg_mgr="zypper"
    elif command -v brew &>/dev/null; then
        pkg_mgr="brew"
    fi

    echo "$pkg_mgr"
}

# =============================================================================
# Platform Information Export
# =============================================================================

# Initialize and export platform information
initialize_platform_info() {
    export OS_TYPE
    OS_TYPE="$(detect_os)"

    export ARCH
    ARCH="$(detect_arch)"

    if [[ "$OS_TYPE" == "linux" ]]; then
        export DISTRO_NAME
        DISTRO_NAME="$(detect_distro)"

        export DISTRO_VERSION
        DISTRO_VERSION="$(detect_distro_version)"

        export DISTRO_CODENAME
        DISTRO_CODENAME="$(detect_distro_codename)"
    else
        export DISTRO_NAME="not-applicable"
        export DISTRO_VERSION="not-applicable"
        export DISTRO_CODENAME="not-applicable"
    fi

    export PACKAGE_MANAGER
    PACKAGE_MANAGER="$(detect_package_manager)"

    export IS_WSL
    if is_wsl; then
        IS_WSL="true"
    else
        IS_WSL="false"
    fi

    export IS_CONTAINER
    if is_container; then
        IS_CONTAINER="true"
    else
        IS_CONTAINER="false"
    fi

    export HAS_SYSTEMD
    if has_systemd; then
        HAS_SYSTEMD="true"
    else
        HAS_SYSTEMD="false"
    fi
}

# Auto-initialize if this script is sourced
initialize_platform_info

# =============================================================================
# Platform Information Display
# =============================================================================

# Display platform information (for debugging)
show_platform_info() {
    echo "Platform Information:"
    echo "  OS Type: $OS_TYPE"
    echo "  Architecture: $ARCH"

    if [[ "$OS_TYPE" == "linux" ]]; then
        echo "  Distribution: $DISTRO_NAME"
        echo "  Version: $DISTRO_VERSION"
        echo "  Codename: $DISTRO_CODENAME"
    fi

    echo "  Package Manager: $PACKAGE_MANAGER"
    echo "  WSL: $IS_WSL"
    echo "  Container: $IS_CONTAINER"
    echo "  Systemd: $HAS_SYSTEMD"
}
