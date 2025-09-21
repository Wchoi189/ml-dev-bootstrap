#!/bin/bash
# =============================================================================
# SSH Setup Module
# Configure SSH keys, client settings, and agent for easier server access
# =============================================================================

# Resolve directories robustly even when sourced
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$MODULE_DIR/.." && pwd)"

# Load config safely while preserving pre-set env overrides
CONFIG_PATH="$REPO_ROOT/config/defaults.conf"
_PRIOR_SSH_SETUP="${SSH_SETUP:-}"
_PRIOR_SSH_KEY_TYPE="${SSH_KEY_TYPE:-}"
_PRIOR_SSH_KEY_BITS="${SSH_KEY_BITS:-}"
[[ -f "$CONFIG_PATH" ]] && source "$CONFIG_PATH"
[[ -n "${_PRIOR_SSH_SETUP}" ]] && export SSH_SETUP="${_PRIOR_SSH_SETUP}"
[[ -n "${_PRIOR_SSH_KEY_TYPE}" ]] && export SSH_KEY_TYPE="${_PRIOR_SSH_KEY_TYPE}"
[[ -n "${_PRIOR_SSH_KEY_BITS}" ]] && export SSH_KEY_BITS="${_PRIOR_SSH_KEY_BITS}"

run_ssh() {
    # Respect toggle. Return 2 to indicate skipped by config.
    if [[ "${SSH_SETUP:-no}" != "yes" ]]; then
        log_info "[ssh] Skipping SSH setup (SSH_SETUP=${SSH_SETUP:-no})"
        return 2
    fi

    log_header "SSH Configuration Setup"

    # Determine target user and home directory
    local target_user
    local target_home
    if [[ $EUID -eq 0 ]]; then
        target_user="${SSH_USER:-vscode}"
        target_home="/home/$target_user"
        # Ensure user exists
        if ! id "$target_user" &>/dev/null; then
            log_warn "[ssh] User $target_user does not exist, falling back to root"
            target_user="root"
            target_home="/root"
        fi
    else
        target_user="$(id -un)"
        target_home="$HOME"
    fi

    log_info "[ssh] Setting up SSH for user: $target_user ($target_home)"

    # Create SSH directory with proper permissions
    local ssh_dir="$target_home/.ssh"
    if [[ $EUID -eq 0 ]]; then
        # Running as root, create directory for target user
        mkdir -p "$ssh_dir"
        chown "$target_user:$target_user" "$ssh_dir"
        chmod 700 "$ssh_dir"
    else
        # Running as user
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi

    # Fix SSH permissions using the utility script if available
    local utils_dir="$(cd "$MODULE_DIR/.." && cd "utils" && pwd)"
    if [[ -x "$utils_dir/fix-ssh-permissions.sh" ]]; then
        log_info "[ssh] Running SSH permissions fix..."
        if [[ $EUID -eq 0 ]]; then
            sudo -u "$target_user" "$utils_dir/fix-ssh-permissions.sh" "$ssh_dir" >/dev/null 2>&1 || log_warn "[ssh] Permission fix had some issues"
        else
            "$utils_dir/fix-ssh-permissions.sh" "$ssh_dir" >/dev/null 2>&1 || log_warn "[ssh] Permission fix had some issues"
        fi
    fi

    # Generate SSH keys if they don't exist
    generate_ssh_keys "$target_user" "$ssh_dir"

    # Setup SSH config file
    setup_ssh_config "$target_user" "$ssh_dir"

    # Setup SSH agent
    setup_ssh_agent "$target_user" "$target_home"

    # Setup known hosts
    setup_known_hosts "$target_user" "$ssh_dir"

    log_success "[ssh] SSH setup completed for $target_user"
    return 0
}

generate_ssh_keys() {
    local target_user="$1"
    local ssh_dir="$2"

    log_info "[ssh] Checking for existing SSH keys..."

    local key_types=("${SSH_KEY_TYPE:-ed25519,rsa}")
    local key_comment="${SSH_KEY_COMMENT:-$target_user@$(hostname)}"

    IFS=',' read -ra KEY_TYPES <<< "$key_types"

    for key_type in "${KEY_TYPES[@]}"; do
        local key_file="$ssh_dir/id_${key_type}"
        local pub_key_file="$key_file.pub"

        # Check if key already exists
        if [[ -f "$key_file" ]]; then
            log_info "[ssh] SSH key $key_file already exists, skipping generation"
            continue
        fi

        log_info "[ssh] Generating $key_type SSH key..."

        local ssh_keygen_cmd="ssh-keygen"
        local keygen_opts=()

        case "$key_type" in
            rsa)
                keygen_opts=(-t rsa -b "${SSH_KEY_BITS:-4096}" -C "$key_comment" -f "$key_file" -N "")
                ;;
            ed25519)
                keygen_opts=(-t ed25519 -C "$key_comment" -f "$key_file" -N "")
                ;;
            ecdsa)
                keygen_opts=(-t ecdsa -b 521 -C "$key_comment" -f "$key_file" -N "")
                ;;
            *)
                log_warn "[ssh] Unsupported key type: $key_type, skipping"
                continue
                ;;
        esac

        if [[ $EUID -eq 0 ]]; then
            # Run as target user
            if ! sudo -u "$target_user" "$ssh_keygen_cmd" "${keygen_opts[@]}"; then
                log_error "[ssh] Failed to generate $key_type key for $target_user"
                continue
            fi
        else
            # Run directly
            if ! "$ssh_keygen_cmd" "${keygen_opts[@]}"; then
                log_error "[ssh] Failed to generate $key_type key"
                continue
            fi
        fi

        # Set proper permissions
        if [[ $EUID -eq 0 ]]; then
            chown "$target_user:$target_user" "$key_file" "$pub_key_file"
        fi
        chmod 600 "$key_file"
        chmod 644 "$pub_key_file"

        log_success "[ssh] Generated $key_type key: $key_file"
    done
}

setup_ssh_config() {
    local target_user="$1"
    local ssh_dir="$2"

    local config_file="$ssh_dir/config"

    # Backup existing config if it exists
    if [[ -f "$config_file" ]] && [[ ! -f "$config_file.backup" ]]; then
        cp "$config_file" "$config_file.backup"
        log_info "[ssh] Backed up existing SSH config to $config_file.backup"
    fi

    log_info "[ssh] Setting up SSH client configuration..."

    # Create SSH config with common settings
    cat > "$config_file" << 'EOF'
# SSH Client Configuration
# Generated by ml-dev-bootstrap

# Global options
Host *
    # Security
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    PubkeyAuthentication yes
    HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa
    KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

    # Performance
    ControlMaster auto
    ControlPath ~/.ssh/master-%r@%h:%p
    ControlPersist 10m

    # User experience
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking ask
    UserKnownHostsFile ~/.ssh/known_hosts
    LogLevel INFO

# Common server aliases
Host dev-server
    HostName dev.example.com
    User dev
    Port 22

Host prod-server
    HostName prod.example.com
    User admin
    Port 22

Host staging
    HostName staging.example.com
    User deploy
    Port 22

# AWS EC2 instances (uncomment and modify as needed)
# Host aws-dev
#     HostName ec2-XX-XX-XX-XX.compute-1.amazonaws.com
#     User ec2-user
#     IdentityFile ~/.ssh/aws-dev.pem

# Host aws-ubuntu
#     HostName ec2-XX-XX-XX-XX.compute-1.amazonaws.com
#     User ubuntu
#     IdentityFile ~/.ssh/aws-ubuntu.pem

# DigitalOcean droplets (uncomment and modify as needed)
# Host do-droplet
#     HostName XXX.XXX.XXX.XXX
#     User root
#     IdentityFile ~/.ssh/do-droplet

# Local development
Host localhost-dev
    HostName localhost
    User vscode
    Port 2222
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

    # Set proper permissions
    if [[ $EUID -eq 0 ]]; then
        chown "$target_user:$target_user" "$config_file"
    fi
    chmod 600 "$config_file"

    log_success "[ssh] SSH config created at $config_file"
}

setup_ssh_agent() {
    local target_user="$1"
    local target_home="$2"

    log_info "[ssh] Setting up SSH agent..."

    # Check if SSH agent is already running
    if [[ -n "${SSH_AGENT_PID:-}" ]] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        log_info "[ssh] SSH agent already running (PID: $SSH_AGENT_PID)"
        return 0
    fi

    # Setup SSH agent in shell profile
    local bashrc="$target_home/.bashrc"
    local profile_script="$target_home/.ssh/agent-setup.sh"

    # Create agent setup script
    cat > "$profile_script" << 'EOF'
#!/bin/bash
# SSH Agent setup script

# Check if agent is already running
if [[ -z "${SSH_AGENT_PID:-}" ]] || ! kill -0 "${SSH_AGENT_PID:-}" 2>/dev/null; then
    # Start SSH agent
    eval "$(ssh-agent -s)" > /dev/null

    # Add default keys if they exist
    for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/id_ecdsa; do
        if [[ -f "$key" ]]; then
            ssh-add "$key" 2>/dev/null
        fi
    done
fi
EOF

    chmod +x "$profile_script"

    # Add to bashrc if not already present
    if ! grep -q "source.*agent-setup.sh" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# SSH Agent setup" >> "$bashrc"
        echo "source ~/.ssh/agent-setup.sh" >> "$bashrc"
        log_info "[ssh] Added SSH agent setup to $bashrc"
    fi

    # Set proper ownership
    if [[ $EUID -eq 0 ]]; then
        chown -R "$target_user:$target_user" "$target_home/.ssh"
    fi

    log_success "[ssh] SSH agent setup configured"
}

setup_known_hosts() {
    local target_user="$1"
    local ssh_dir="$2"

    local known_hosts="$ssh_dir/known_hosts"

    # Create known_hosts file if it doesn't exist
    if [[ ! -f "$known_hosts" ]]; then
        touch "$known_hosts"
        if [[ $EUID -eq 0 ]]; then
            chown "$target_user:$target_user" "$known_hosts"
        fi
        chmod 600 "$known_hosts"
        log_info "[ssh] Created known_hosts file"
    fi

    # Add common host keys (GitHub, GitLab, etc.)
    log_info "[ssh] Adding common host keys to known_hosts..."

    # GitHub
    if ! ssh-keygen -F github.com -f "$known_hosts" >/dev/null 2>&1; then
        echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> "$known_hosts" 2>/dev/null || true
    fi

    # GitLab
    if ! ssh-keygen -F gitlab.com -f "$known_hosts" >/dev/null 2>&1; then
        echo "gitlab.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsj2bNKTBSpIYDEGk9KxsGh3mySTRgMtXL583qmBpzeQ+jqCMRgBqB98u3z++J1sKlXHWfM9dyhSevkMwSbhoR8XIq/U0tCNyaxZcDhR2cz8MPTai1B1TGiKbRLHQGD6woRsF+3PfzbLzHm4OLG3Q+jZNFLD4EAIeTt613pKW+jeOCuRozC4QCiMPsjSTyW+4iIcSOE5/ZJKv3lxdefwsGsxF7DAQTt/QFp1fPqc4WE1XKTggZG7hgQ6HNM4tGZBlNp6pCQbBk1R3+OGgRn4xLKAGBj7wADj5lG4lbKfYtF3rKdEB0tBZn7QK8I2EbGQNj2XMoiccjcPcgX5VqkVQ" >> "$known_hosts" 2>/dev/null || true
    fi

    log_success "[ssh] Known hosts setup completed"
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_ssh
fi