#!/bin/bash

# =============================================================================
# APT Sources Management Module
# Configure regional APT mirrors and sources for faster package downloads
# =============================================================================

# Available mirrors configuration
declare -A MIRRORS=(
    ["kakao"]="http://mirror.kakao.com/ubuntu/"
    ["naver"]="http://mirror.navercorp.com/ubuntu/"
    ["daum"]="http://ftp.daum.net/ubuntu/"
    ["ubuntu-official"]="http://archive.ubuntu.com/ubuntu/"
    ["us-west"]="http://us-west-2.ec2.archive.ubuntu.com/ubuntu/"
    ["us-east"]="http://us-east-1.ec2.archive.ubuntu.com/ubuntu/"
    ["eu-central"]="http://eu-central-1.ec2.archive.ubuntu.com/ubuntu/"
    ["asia-east"]="http://asia-east-1.ec2.archive.ubuntu.com/ubuntu/"
)

# Ubuntu codenames mapping
declare -A UBUNTU_CODENAMES=(
    ["20.04"]="focal"
    ["21.04"]="hirsute"
    ["21.10"]="impish"
    ["22.04"]="jammy"
    ["22.10"]="kinetic"
    ["23.04"]="lunar"
    ["23.10"]="mantic"
    ["24.04"]="noble"
)

# =============================================================================
# Functions
# =============================================================================

detect_ubuntu_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            UBUNTU_VERSION="$VERSION_ID"
            CODENAME="${UBUNTU_CODENAMES[$UBUNTU_VERSION]}"
            if [[ -z "$CODENAME" ]]; then
                log_error "Unsupported Ubuntu version: $UBUNTU_VERSION"
                return 1
            fi
            log_info "Detected Ubuntu $UBUNTU_VERSION ($CODENAME)"
            return 0
        fi
    fi
    log_error "Unable to detect Ubuntu version"
    return 1
}

backup_sources_list() {
    local backup_file="/etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup of current sources.list to $backup_file"
    sudo cp /etc/apt/sources.list "$backup_file" || {
        log_error "Failed to create backup"
        return 1
    }
    return 0
}

generate_sources_list() {
    local mirror="$1"
    local codename="$2"
    local include_sources="${3:-false}"

    cat << EOF
# $mirror Ubuntu $UBUNTU_VERSION LTS ($codename) Repository
deb $mirror $codename main restricted universe multiverse
deb $mirror $codename-updates main restricted universe multiverse
deb $mirror $codename-backports main restricted universe multiverse
deb $mirror $codename-security main restricted universe multiverse
EOF

    if [[ "$include_sources" == "true" ]]; then
        cat << EOF
# Source packages
deb-src $mirror $codename main restricted universe multiverse
deb-src $mirror $codename-updates main restricted universe multiverse
deb-src $mirror $codename-backports main restricted universe multiverse
deb-src $mirror $codename-security main restricted universe multiverse
EOF
    fi
}

configure_mirror() {
    local mirror_name="$1"
    local mirror_url="${MIRRORS[$mirror_name]}"

    if [[ -z "$mirror_url" ]]; then
        log_error "Unknown mirror: $mirror_name"
        return 1
    fi

    log_info "Configuring APT sources to use $mirror_name mirror ($mirror_url)"

    # Backup current sources.list
    backup_sources_list || return 1

    # Generate new sources.list
    local sources_content
    sources_content=$(generate_sources_list "$mirror_url" "$CODENAME" "false")

    # Write to sources.list
    echo "$sources_content" | sudo tee /etc/apt/sources.list > /dev/null || {
        log_error "Failed to write sources.list"
        return 1
    }

    log_success "APT sources configured to use $mirror_name mirror"
    log_info "Run 'sudo apt update' to refresh package lists"
    return 0
}

show_available_mirrors() {
    log_info "Available APT mirrors:"
    for mirror in "${!MIRRORS[@]}"; do
        printf "  %-15s %s\n" "$mirror" "${MIRRORS[$mirror]}"
    done
}

interactive_mirror_selection() {
    echo "Available mirrors:"
    local i=1
    local mirror_names=("${!MIRRORS[@]}")
    for mirror in "${mirror_names[@]}"; do
        printf "%d) %-15s %s\n" $i "$mirror" "${MIRRORS[$mirror]}"
        ((i++))
    done
    echo
    read -p "Select mirror (1-${#mirror_names[@]}): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#mirror_names[@]} )); then
        local selected_mirror="${mirror_names[$((choice-1))]}"
        configure_mirror "$selected_mirror"
    else
        log_error "Invalid selection: $choice"
        return 1
    fi
}

# =============================================================================
# Main Sources Setup Function
# =============================================================================

run_sources() {
    log_header "APT Sources Configuration"

    # Detect Ubuntu version
    detect_ubuntu_version || return 1

    # Check if running interactively
    if [[ -t 0 ]]; then
        # Interactive mode
        echo "Current APT sources configuration:"
        echo "=================================="
        cat /etc/apt/sources.list | head -10
        echo "..."
        echo
        echo "Choose an option:"
        echo "1) Select from available mirrors"
        echo "2) Show available mirrors"
        echo "3) Configure specific mirror (advanced)"
        echo "4) Restore from backup"
        echo
        read -p "Your choice (1-4): " choice

        case $choice in
            1)
                interactive_mirror_selection
                ;;
            2)
                show_available_mirrors
                ;;
            3)
                read -p "Enter mirror name: " mirror_name
                configure_mirror "$mirror_name"
                ;;
            4)
                echo "Available backups:"
                ls -la /etc/apt/sources.list.backup.* 2>/dev/null || echo "No backups found"
                read -p "Enter backup filename (or 'latest' for most recent): " backup_file
                if [[ "$backup_file" == "latest" ]]; then
                    backup_file=$(ls -t /etc/apt/sources.list.backup.* 2>/dev/null | head -1)
                fi
                if [[ -f "$backup_file" ]]; then
                    sudo cp "$backup_file" /etc/apt/sources.list
                    log_success "Restored from $backup_file"
                else
                    log_error "Backup file not found: $backup_file"
                fi
                ;;
            *)
                log_error "Invalid choice: $choice"
                return 1
                ;;
        esac
    else
        # Non-interactive mode - use default mirror
        log_info "Non-interactive mode: configuring with Kakao mirror (recommended for Korea)"
        configure_mirror "kakao"
    fi

    return 0
}
