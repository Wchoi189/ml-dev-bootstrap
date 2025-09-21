#!/bin/bash
# =============================================================================
# SSH Permissions Fix Utility
# Fixes common SSH permission issues, especially for WSL users
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_header() {
    echo ""
    echo -e "${BLUE}=== $* ===${NC}"
    echo ""
}

# Check if running on WSL
is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -n "${WSLENV:-}" ]] || uname -r | grep -qi microsoft
}

# Main permission fixing function
fix_ssh_permissions() {
    local ssh_dir="${1:-$HOME/.ssh}"

    log_header "SSH Permissions Fix Utility"
    log_info "Target SSH directory: $ssh_dir"

    # Check if SSH directory exists
    if [[ ! -d "$ssh_dir" ]]; then
        log_warn "SSH directory does not exist: $ssh_dir"
        log_info "Creating SSH directory..."
        mkdir -p "$ssh_dir"
    fi

    # Fix directory permissions
    log_info "Setting SSH directory permissions (700)..."
    chmod 700 "$ssh_dir"

    # Count files before fixing
    local private_keys=$(find "$ssh_dir" -name 'id_*' ! -name '*.pub' -type f 2>/dev/null | wc -l)
    local public_keys=$(find "$ssh_dir" -name '*.pub' -type f 2>/dev/null | wc -l)
    local auth_keys=$(find "$ssh_dir" -name 'authorized_keys*' -type f 2>/dev/null | wc -l)
    local config_files=$(find "$ssh_dir" -name 'config*' -type f 2>/dev/null | wc -l)

    log_info "Found $private_keys private keys, $public_keys public keys"
    log_info "Found $auth_keys authorized_keys files, $config_files config files"

    # Fix private key permissions (600)
    if [[ $private_keys -gt 0 ]]; then
        log_info "Setting private key permissions (600)..."
        find "$ssh_dir" -name 'id_*' ! -name '*.pub' -type f -exec chmod 600 {} \;
    fi

    # Fix public key permissions (644)
    if [[ $public_keys -gt 0 ]]; then
        log_info "Setting public key permissions (644)..."
        find "$ssh_dir" -name '*.pub' -type f -exec chmod 644 {} \;
    fi

    # Fix authorized_keys permissions (600)
    if [[ $auth_keys -gt 0 ]]; then
        log_info "Setting authorized_keys permissions (600)..."
        find "$ssh_dir" -name 'authorized_keys*' -type f -exec chmod 600 {} \;
    fi

    # Fix config file permissions (600)
    if [[ $config_files -gt 0 ]]; then
        log_info "Setting SSH config permissions (600)..."
        find "$ssh_dir" -name 'config*' -type f -exec chmod 600 {} \;
    fi

    # Fix known_hosts permissions (644)
    if [[ -f "$ssh_dir/known_hosts" ]]; then
        log_info "Setting known_hosts permissions (644)..."
        chmod 644 "$ssh_dir/known_hosts"
    fi

    # WSL-specific fixes
    if is_wsl; then
        log_info "WSL detected - applying WSL-specific fixes..."

        # Ensure proper ownership (sometimes WSL has ownership issues)
        if [[ -n "${USER:-}" ]]; then
            log_info "Ensuring proper ownership for user: $USER"
            chown -R "$USER:$USER" "$ssh_dir" 2>/dev/null || log_warn "Could not set ownership (this is normal in some WSL setups)"
        fi

        # Check for common WSL permission issues
        if [[ ! -r "$ssh_dir" ]]; then
            log_error "SSH directory is not readable. This may be a WSL filesystem issue."
            log_info "Try running: chmod +r ~/.ssh"
        fi
    fi

    # Verify permissions
    log_info "Verifying permissions..."
    local issues=0

    # Check directory permissions
    if [[ $(stat -c '%a' "$ssh_dir" 2>/dev/null || stat -f '%A' "$ssh_dir" 2>/dev/null) != "700" ]]; then
        log_warn "SSH directory permissions are not 700"
        ((issues++))
    fi

    # Check for world-readable private keys
    if find "$ssh_dir" -name 'id_*' ! -name '*.pub' -type f -perm /022 2>/dev/null | grep -q .; then
        log_warn "Some private keys are world-readable"
        ((issues++))
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "All SSH permissions are correctly set!"
    else
        log_warn "Found $issues permission issues. You may need to address them manually."
    fi

    # Show current status
    echo ""
    log_info "Current SSH directory status:"
    ls -la "$ssh_dir" | head -10

    # Show SSH agent status if running
    if [[ -n "${SSH_AGENT_PID:-}" ]]; then
        log_info "SSH agent is running (PID: $SSH_AGENT_PID)"
    else
        log_info "SSH agent is not running. Consider starting it with: eval \"\$(ssh-agent -s)\""
    fi
}

# Show usage information
show_usage() {
    cat << EOF
SSH Permissions Fix Utility

USAGE:
    $0 [OPTIONS] [SSH_DIR]

ARGUMENTS:
    SSH_DIR    SSH directory to fix (default: ~/.ssh)

OPTIONS:
    -h, --help     Show this help message
    -v, --verbose  Enable verbose output
    --dry-run      Show what would be changed without making changes

EXAMPLES:
    $0                    # Fix permissions in ~/.ssh
    $0 /home/user/.ssh    # Fix permissions in custom SSH directory
    $0 --dry-run          # Show what would be changed

COMMON ISSUES THIS FIXES:
    - SSH directory permissions (should be 700)
    - Private key permissions (should be 600)
    - Public key permissions (should be 644)
    - authorized_keys permissions (should be 600)
    - WSL-specific permission issues

EOF
}

# Parse command line arguments
parse_args() {
    DRY_RUN=false
    VERBOSE=false
    SSH_DIR=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$SSH_DIR" ]]; then
                    SSH_DIR="$1"
                else
                    log_error "Too many arguments"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Set default SSH directory
    if [[ -z "$SSH_DIR" ]]; then
        SSH_DIR="$HOME/.ssh"
    fi

    # Expand tilde
    SSH_DIR="${SSH_DIR/#\~/$HOME}"
}

# Main function
main() {
    parse_args "$@"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
        log_info "Would fix permissions in: $SSH_DIR"
        exit 0
    fi

    fix_ssh_permissions "$SSH_DIR"
}

# Run main function
main "$@"