#!/bin/bash

# =============================================================================
# Color Shell Prompt Configuration Module
# Sets up beautiful, informative color prompts for development
# =============================================================================

# Prompt configuration
PROMPT_STYLE="${PROMPT_STYLE:-modern}"
SHOW_GIT_INFO="${SHOW_GIT_INFO:-true}"
SHOW_CONDA_ENV="${SHOW_CONDA_ENV:-true}"
SHOW_PYTHON_VERSION="${SHOW_PYTHON_VERSION:-false}"
SHOW_NODE_VERSION="${SHOW_NODE_VERSION:-false}"

# Color definitions
declare -A COLORS=(
    ["BLACK"]='\033[0;30m'
    ["RED"]='\033[0;31m'
    ["GREEN"]='\033[0;32m'
    ["YELLOW"]='\033[0;33m'
    ["BLUE"]='\033[0;34m'
    ["PURPLE"]='\033[0;35m'
    ["CYAN"]='\033[0;36m'
    ["WHITE"]='\033[0;37m'
    ["BRIGHT_BLACK"]='\033[1;30m'
    ["BRIGHT_RED"]='\033[1;31m'
    ["BRIGHT_GREEN"]='\033[1;32m'
    ["BRIGHT_YELLOW"]='\033[1;33m'
    ["BRIGHT_BLUE"]='\033[1;34m'
    ["BRIGHT_PURPLE"]='\033[1;35m'
    ["BRIGHT_CYAN"]='\033[1;36m'
    ["BRIGHT_WHITE"]='\033[1;37m'
    ["RESET"]='\033[0m'
)

# =============================================================================
# Main Prompt Setup Function
# =============================================================================

run_prompt() {
    log_header "Color Shell Prompt Setup"

    # --- THIS IS THE FIX ---
    # Source common configuration to ensure variables are loaded
    # Resolve repo root robustly for config sourcing
    local _MOD_DIR
    _MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local _REPO_ROOT
    _REPO_ROOT="$(cd "$_MOD_DIR/.." && pwd)"
    if [[ -f "$_REPO_ROOT/config/defaults.conf" ]]; then
        source "$_REPO_ROOT/config/defaults.conf"
    fi

    # Determine target user and home directory
    local target_user target_home
    if [[ $EUID -eq 0 ]]; then
        # Running as root - configure for root user
        target_user="root"
        target_home="/root"
        log_info "Configuring prompt for root user"
    else
        # Running as regular user - configure for dev-user
        target_user="${DEV_USERNAME:-${USERNAME:-vscode-user}}"
        target_home="/home/$target_user"
        log_info "Configuring prompt for user: $target_user"
    fi

    # Update DEV_* variables for compatibility with existing functions
    DEV_USERNAME="$target_user"
    DEV_HOME="$target_home"
    DEV_GROUP="${DEV_GROUP:-${USER_GROUP:-vscode}}"

    local total_steps=5
    local current_step=0

    # Step 1: Validate prompt configuration
    ((current_step++))
    log_step $current_step $total_steps "Validating prompt configuration"
    validate_prompt_config || {
        log_error "Prompt configuration validation failed"
        return 1
    }

    # Step 2: Install prompt dependencies
    ((current_step++))
    log_step $current_step $total_steps "Installing prompt dependencies"
    install_prompt_dependencies || {
        log_warn "Some prompt dependencies failed to install"
    }

    # Step 3: Create prompt functions
    ((current_step++))
    log_step $current_step $total_steps "Creating prompt functions"
    create_prompt_functions || {
        log_error "Failed to create prompt functions"
        return 1
    }

    # Step 4: Configure user prompt
    ((current_step++))
    log_step $current_step $total_steps "Configuring user prompt"
    configure_user_prompt || {
        log_error "Failed to configure user prompt"
        return 1
    }

    # Step 5: Test prompt functionality
    ((current_step++))
    log_step $current_step $total_steps "Testing prompt functionality"
    test_prompt_functionality || {
        log_warn "Prompt functionality test had issues"
    }

    log_success "Color prompt setup completed successfully!"
    show_prompt_info
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_prompt_config() {
    log_info "Validating prompt configuration..."

    # Validate prompt style
    local valid_styles=("simple" "modern" "powerline" "minimal")
    local style_valid=false

    for style in "${valid_styles[@]}"; do
        if [[ "$PROMPT_STYLE" == "$style" ]]; then
            style_valid=true
            break
        fi
    done

    if [[ "$style_valid" != "true" ]]; then
        log_warn "Invalid prompt style '$PROMPT_STYLE', using 'modern'"
        export PROMPT_STYLE="modern"
    fi

    # Check terminal color support
    if [[ -z "${TERM:-}" ]]; then
        log_warn "TERM environment variable not set, colors may not work"
    elif [[ "$TERM" == "dumb" ]]; then
        log_warn "Terminal does not support colors, using simple prompt"
        export PROMPT_STYLE="simple"
    fi

    log_success "Prompt configuration validated"
    return 0
}

# =============================================================================
# Dependency Installation
# =============================================================================

install_prompt_dependencies() {
    log_info "Installing prompt dependencies..."

    local dependencies=()

    # Git for git prompt info
    if [[ "$SHOW_GIT_INFO" == "true" ]] && ! check_command "git"; then
        dependencies+=("git")
    fi

    # Install dependencies if needed
    if [[ ${#dependencies[@]} -gt 0 ]]; then
        install_packages "${dependencies[@]}" || {
            log_error "Failed to install prompt dependencies"
            return 1
        }
    else
        log_success "All prompt dependencies already available"
    fi

    return 0
}

# =============================================================================
# Prompt Function Creation
# =============================================================================

create_prompt_functions() {
    log_info "Creating prompt functions..."

    local prompt_functions_file="$DEV_HOME/.bash_prompt_functions"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create prompt functions file"
        return 0
    fi

    # Create prompt functions file
    cat > "$prompt_functions_file" << 'EOF'
#!/bin/bash
# Bash prompt functions for development environment

# Color definitions
declare -A PROMPT_COLORS=(
    ["BLACK"]='\033[0;30m'
    ["RED"]='\033[0;31m'
    ["GREEN"]='\033[0;32m'
    ["YELLOW"]='\033[0;33m'
    ["BLUE"]='\033[0;34m'
    ["PURPLE"]='\033[0;35m'
    ["CYAN"]='\033[0;36m'
    ["WHITE"]='\033[0;37m'
    ["BRIGHT_BLACK"]='\033[1;30m'
    ["BRIGHT_RED"]='\033[1;31m'
    ["BRIGHT_GREEN"]='\033[1;32m'
    ["BRIGHT_YELLOW"]='\033[1;33m'
    ["BRIGHT_BLUE"]='\033[1;34m'
    ["BRIGHT_PURPLE"]='\033[1;35m'
    ["BRIGHT_CYAN"]='\033[1;36m'
    ["BRIGHT_WHITE"]='\033[1;37m'
    ["RESET"]='\033[0m'
)

# Git prompt functions
__git_ps1_show_upstream() {
    local upstream=""
    local verbose=""
    local name=""

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        return
    fi

    # Get current branch
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

    if [[ -n "$branch" ]]; then
        echo "$branch"
    fi
}

__git_ps1() {
    local branch=$(__git_ps1_show_upstream)
    if [[ -n "$branch" ]]; then
        # Check for uncommitted changes
        local status=""
        if ! git diff --quiet 2>/dev/null; then
            status="*"
        fi

        # Check for untracked files
        if [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]]; then
            status="${status}+"
        fi

        # Check for staged changes
        if ! git diff --cached --quiet 2>/dev/null; then
            status="${status}^"
        fi

        echo " (${branch}${status})"
    fi
}

# Conda environment function
__conda_ps1() {
    if [[ -n "${CONDA_DEFAULT_ENV:-}" ]] && [[ "$CONDA_DEFAULT_ENV" != "base" ]]; then
        echo " (${CONDA_DEFAULT_ENV})"
    fi
}

# Python version function
__python_ps1() {
    if command -v python3 >/dev/null 2>&1; then
        local py_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
        if [[ -n "$py_version" ]]; then
            echo " [py:${py_version}]"
        fi
    fi
}

# Node version function
__node_ps1() {
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version 2>/dev/null | sed 's/^v//')
        if [[ -n "$node_version" ]]; then
            echo " [node:${node_version}]"
        fi
    fi
}

# Exit status function
__exit_status_ps1() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo " [${exit_code}]"
    fi
    return $exit_code
}

# Load average function
__load_ps1() {
    if [[ -f /proc/loadavg ]]; then
        local load=$(cut -d' ' -f1 /proc/loadavg)
        echo " [${load}]"
    fi
}

# Time function
__time_ps1() {
    date '+%H:%M:%S'
}

# Directory shortener
__short_pwd() {
    local pwd_length=30
    local pwd="${PWD/#$HOME/~}"

    if [[ ${#pwd} -gt $pwd_length ]]; then
        echo "...${pwd: -$((pwd_length-3))}"
    else
        echo "$pwd"
    fi
}

# Simple prompt style
__prompt_simple() {
    PS1='\u@\h:\w\$ '
}

# Modern prompt style
__prompt_modern() {
    local exit_status=$(__exit_status_ps1)
    local git_info=""
    local conda_info=""
    local python_info=""
    local node_info=""

    # Add git info if enabled
    if [[ "${SHOW_GIT_INFO:-true}" == "true" ]]; then
        git_info=$(__git_ps1)
    fi

    # Add conda info if enabled
    if [[ "${SHOW_CONDA_ENV:-true}" == "true" ]]; then
        conda_info=$(__conda_ps1)
    fi

    # Add python info if enabled
    if [[ "${SHOW_PYTHON_VERSION:-false}" == "true" ]]; then
        python_info=$(__python_ps1)
    fi

    # Add node info if enabled
    if [[ "${SHOW_NODE_VERSION:-false}" == "true" ]]; then
        node_info=$(__node_ps1)
    fi

    # Build prompt
    PS1=""
    PS1+="\[${PROMPT_COLORS[BRIGHT_GREEN]}\]\u"                    # username
    PS1+="\[${PROMPT_COLORS[WHITE]}\]@"                           # @
    PS1+="\[${PROMPT_COLORS[BRIGHT_BLUE]}\]\h"                    # hostname
    PS1+="\[${PROMPT_COLORS[WHITE]}\]:"                           # :
    PS1+="\[${PROMPT_COLORS[BRIGHT_YELLOW]}\]\$(__short_pwd)"     # directory
    PS1+="\[${PROMPT_COLORS[BRIGHT_PURPLE]}\]${git_info}"         # git info
    PS1+="\[${PROMPT_COLORS[BRIGHT_CYAN]}\]${conda_info}"         # conda env
    PS1+="\[${PROMPT_COLORS[YELLOW]}\]${python_info}"             # python version
    PS1+="\[${PROMPT_COLORS[GREEN]}\]${node_info}"                # node version
    PS1+="\[${PROMPT_COLORS[BRIGHT_RED]}\]${exit_status}"         # exit status
    PS1+="\[${PROMPT_COLORS[RESET]}\]"                            # reset colors
    PS1+="\n\$ "                                                  # newline and prompt
}

# Powerline-style prompt
__prompt_powerline() {
    local git_info=$(__git_ps1)
    local conda_info=$(__conda_ps1)

    PS1=""
    PS1+="\[${PROMPT_COLORS[WHITE]}\]\[${PROMPT_COLORS[BLUE]}\] \u@\h "
    PS1+="\[${PROMPT_COLORS[BLUE]}\]\[${PROMPT_COLORS[YELLOW]}\]"
    PS1+="\[${PROMPT_COLORS[BLACK]}\] \$(__short_pwd) "

    if [[ -n "$git_info" ]]; then
        PS1+="\[${PROMPT_COLORS[YELLOW]}\]\[${PROMPT_COLORS[GREEN]}\]"
        PS1+="\[${PROMPT_COLORS[BLACK]}\]${git_info} "
    fi

    if [[ -n "$conda_info" ]]; then
        PS1+="\[${PROMPT_COLORS[GREEN]}\]\[${PROMPT_COLORS[CYAN]}\]"
        PS1+="\[${PROMPT_COLORS[BLACK]}\]${conda_info} "
    fi

    PS1+="\[${PROMPT_COLORS[CYAN]}\]\[${PROMPT_COLORS[RESET]}\] "
    PS1+="\n\$ "
}

# Minimal prompt style
__prompt_minimal() {
    local git_info=""
    if [[ "${SHOW_GIT_INFO:-true}" == "true" ]]; then
        git_info=$(__git_ps1)
    fi

    PS1="\[${PROMPT_COLORS[BRIGHT_BLUE]}\]\w"
    PS1+="\[${PROMPT_COLORS[BRIGHT_PURPLE]}\]${git_info}"
    PS1+="\[${PROMPT_COLORS[RESET]}\] \$ "
}

# Set prompt based on style
__set_prompt() {
    case "${PROMPT_STYLE:-modern}" in
        "simple")
            __prompt_simple
            ;;
        "powerline")
            __prompt_powerline
            ;;
        "minimal")
            __prompt_minimal
            ;;
        *)
            __prompt_modern
            ;;
    esac
}

# Initialize prompt
__init_prompt() {
    # Set up PROMPT_COMMAND to update prompt
    PROMPT_COMMAND="__set_prompt"

    # Set initial prompt
    __set_prompt
}

# Export functions
export -f __git_ps1 __conda_ps1 __python_ps1 __node_ps1
export -f __exit_status_ps1 __load_ps1 __time_ps1 __short_pwd
export -f __prompt_simple __prompt_modern __prompt_powerline __prompt_minimal
export -f __set_prompt __init_prompt
EOF

    # Set ownership and permissions
    chown "$DEV_USERNAME:$DEV_GROUP" "$prompt_functions_file"
    chmod 644 "$prompt_functions_file"

    log_success "Prompt functions created successfully"
    return 0
}

# =============================================================================
# User Prompt Configuration
# =============================================================================

configure_user_prompt() {
    log_info "Configuring user prompt..."

    # Add prompt configuration to user's .bashrc
    configure_bashrc_prompt || {
        log_error "Failed to configure .bashrc prompt"
        return 1
    }

    # Create prompt configuration file
    create_prompt_config || {
        log_warn "Failed to create prompt configuration file"
    }

    log_success "User prompt configured successfully"
    return 0
}

configure_bashrc_prompt() {
    local bashrc_file="$DEV_HOME/.bashrc"

    log_debug "Configuring prompt in .bashrc"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would configure prompt in .bashrc"
        return 0
    fi

    if [[ ! -f "$bashrc_file" ]]; then
        log_error ".bashrc file not found: $bashrc_file"
        return 1
    fi

    # Check if prompt configuration already exists
    if grep -q "bash_prompt_functions" "$bashrc_file"; then
        log_debug "Prompt configuration already exists in .bashrc"
        return 0
    fi

    # Add prompt configuration
    cat >> "$bashrc_file" << EOF

# === Color Prompt Configuration (added by setup-utility) ===
# Load prompt functions
if [ -f ~/.bash_prompt_functions ]; then
    source ~/.bash_prompt_functions

    # Set prompt style
    export PROMPT_STYLE="${PROMPT_STYLE}"
    export SHOW_GIT_INFO="${SHOW_GIT_INFO}"
    export SHOW_CONDA_ENV="${SHOW_CONDA_ENV}"
    export SHOW_PYTHON_VERSION="${SHOW_PYTHON_VERSION}"
    export SHOW_NODE_VERSION="${SHOW_NODE_VERSION}"

    # Initialize prompt
    __init_prompt
fi
# === End Color Prompt Configuration ===
EOF

    # Set ownership
    chown "$DEV_USERNAME:$DEV_GROUP" "$bashrc_file"

    log_debug "Prompt configuration added to .bashrc"
    return 0
}

create_prompt_config() {
    local config_file="$DEV_HOME/.bash_prompt_config"

    log_debug "Creating prompt configuration file"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create prompt configuration file"
        return 0
    fi

    cat > "$config_file" << EOF
# Bash Prompt Configuration
# This file allows you to customize your shell prompt

# Prompt style: simple, modern, powerline, minimal
PROMPT_STYLE="${PROMPT_STYLE}"

# Show git branch and status
SHOW_GIT_INFO="${SHOW_GIT_INFO}"

# Show conda environment
SHOW_CONDA_ENV="${SHOW_CONDA_ENV}"

# Show Python version
SHOW_PYTHON_VERSION="${SHOW_PYTHON_VERSION}"

# Show Node.js version
SHOW_NODE_VERSION="${SHOW_NODE_VERSION}"

# Custom prompt colors (uncomment to override)
# PROMPT_USER_COLOR='\033[1;32m'      # Bright green
# PROMPT_HOST_COLOR='\033[1;34m'      # Bright blue
# PROMPT_PATH_COLOR='\033[1;33m'      # Bright yellow
# PROMPT_GIT_COLOR='\033[1;35m'       # Bright purple

# To apply changes, run: source ~/.bashrc
EOF

    chown "$DEV_USERNAME:$DEV_GROUP" "$config_file"
    chmod 644 "$config_file"

    log_debug "Prompt configuration file created"
    return 0
}

# =============================================================================
# Testing Functions
# =============================================================================

test_prompt_functionality() {
    log_info "Testing prompt functionality..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would test prompt functionality"
        return 0
    fi

    # Test if user can source the prompt functions
    if ! check_user_exists "$DEV_USERNAME"; then
        log_debug "Development user does not exist, skipping prompt test"
        return 0
    fi

    # Test prompt functions loading
    local test_result=$(sudo -u "$DEV_USERNAME" -i bash -c "
        source ~/.bash_prompt_functions 2>/dev/null && echo 'SUCCESS' || echo 'FAILED'
    " 2>/dev/null)

    if [[ "$test_result" == "SUCCESS" ]]; then
        log_success "Prompt functions load successfully"
    else
        log_error "Prompt functions failed to load"
        return 1
    fi

    # Test git prompt function (if git is available)
    if check_command "git"; then
        local git_test=$(sudo -u "$DEV_USERNAME" -i bash -c "
            source ~/.bash_prompt_functions 2>/dev/null
            cd /tmp && git init test_repo >/dev/null 2>&1
            cd test_repo && __git_ps1 2>/dev/null && echo 'GIT_OK'
            cd .. && rm -rf test_repo
        " 2>/dev/null)

        if [[ "$git_test" == *"GIT_OK"* ]]; then
            log_success "Git prompt function working"
        else
            log_warn "Git prompt function may have issues"
        fi
    fi

    # Test conda prompt function (if conda is available)
    if [[ -n "${DETECTED_CONDA_PATH:-}" ]]; then
        local conda_test=$(sudo -u "$DEV_USERNAME" -i bash -c "
            source ~/.bash_prompt_functions 2>/dev/null
            export CONDA_DEFAULT_ENV='test_env'
            __conda_ps1 2>/dev/null && echo 'CONDA_OK'
        " 2>/dev/null)

        if [[ "$conda_test" == *"CONDA_OK"* ]]; then
            log_success "Conda prompt function working"
        else
            log_warn "Conda prompt function may have issues"
        fi
    fi

    log_success "Prompt functionality test completed"
    return 0
}

# =============================================================================
# Information Display Functions
# =============================================================================

show_prompt_info() {
    log_header "Color Prompt Configuration Summary"

    echo "Prompt Configuration:"
    echo "  Style: $PROMPT_STYLE"
    echo "  Git info: $SHOW_GIT_INFO"
    echo "  Conda environment: $SHOW_CONDA_ENV"
    echo "  Python version: $SHOW_PYTHON_VERSION"
    echo "  Node.js version: $SHOW_NODE_VERSION"
    echo ""

    echo "Configuration Files:"
    local config_files=(".bash_prompt_functions" ".bash_prompt_config")
    for file in "${config_files[@]}"; do
        local full_path="$DEV_HOME/$file"
        if [[ -f "$full_path" ]]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (missing)"
        fi
    done

    echo ""
    echo "Bashrc Integration:"
    if [[ -f "$DEV_HOME/.bashrc" ]] && grep -q "bash_prompt_functions" "$DEV_HOME/.bashrc"; then
        echo "  ✓ Prompt configuration added to .bashrc"
    else
        echo "  ✗ Prompt configuration not found in .bashrc"
    fi

    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        echo ""
        echo "Available Prompt Styles:"
        echo "  • simple    - Basic username@hostname:path$ prompt"
        echo "  • modern    - Colorful multi-line prompt with git/conda info"
        echo "  • powerline - Powerline-style prompt with segments"
        echo "  • minimal   - Clean minimal prompt with git info"

        echo ""
        echo "Prompt Features:"
        echo "  • Git branch and status indicators"
        echo "  • Conda environment display"
        echo "  • Exit status indication"
        echo "  • Directory path shortening"
        echo "  • Optional Python/Node version display"
    else
        echo ""
        echo "[DRY RUN] Detailed prompt information would be displayed here"
    fi

    log_separator

    # Show usage instructions
    log_info "Usage Instructions:"
    echo "  • Prompt will be active in new shell sessions"
    echo "  • Reload current session: source ~/.bashrc"
    echo "  • Change style: edit PROMPT_STYLE in ~/.bash_prompt_config"
    echo "  • Toggle features: edit SHOW_* variables in config file"
    echo "  • Test prompt: start new bash session as user"
}

# =============================================================================
# Utility Functions
# =============================================================================

change_prompt_style() {
    local new_style="$1"

    log_info "Changing prompt style to: $new_style"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would change prompt style to: $new_style"
        return 0
    fi

    # Validate style
    local valid_styles=("simple" "modern" "powerline" "minimal")
    local style_valid=false

    for style in "${valid_styles[@]}"; do
        if [[ "$new_style" == "$style" ]]; then
            style_valid=true
            break
        fi
    done

    if [[ "$style_valid" != "true" ]]; then
        log_error "Invalid prompt style: $new_style"
        log_info "Valid styles: ${valid_styles[*]}"
        return 1
    fi

    # Update configuration file
    local config_file="$DEV_HOME/.bash_prompt_config"
    if [[ -f "$config_file" ]]; then
        sed -i "s/^PROMPT_STYLE=.*/PROMPT_STYLE=\"$new_style\"/" "$config_file"
        log_success "Prompt style updated in configuration file"
    fi

    # Update environment variable
    export PROMPT_STYLE="$new_style"

    log_success "Prompt style changed to: $new_style"
    log_info "Reload shell to see changes: source ~/.bashrc"
    return 0
}

demo_prompt_styles() {
    log_header "Prompt Style Demonstration"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would demonstrate prompt styles"
        return 0
    fi

    echo "Here are examples of different prompt styles:"
    echo ""

    echo "1. Simple style:"
    echo "   dev-user@container:/home/dev-user$ "
    echo ""

    echo "2. Modern style:"
    echo "   dev-user@container:/home/dev-user (main*) (myenv)"
    echo "   $ "
    echo ""

    echo "3. Powerline style:"
    echo "   dev-user@container  ~/project  main*  myenv "
    echo "   $ "
    echo ""

    echo "4. Minimal style:"
    echo "   ~/project (main*) $ "
    echo ""

    echo "Legend:"
    echo "  • (main*) - Git branch with uncommitted changes"
    echo "  • (myenv) - Active conda environment"
    echo "  • Colors vary by terminal support"

    log_separator
}

reset_prompt_config() {
    log_info "Resetting prompt configuration to defaults..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would reset prompt configuration"
        return 0
    fi

    if ! confirm_action "This will reset all prompt customizations. Continue?" "n"; then
        log_info "Prompt reset cancelled"
        return 0
    fi

    # Remove prompt configuration from .bashrc
    local bashrc_file="$DEV_HOME/.bashrc"
    if [[ -f "$bashrc_file" ]]; then
        sed -i '/=== Color Prompt Configuration/,/=== End Color Prompt Configuration ===/d' "$bashrc_file"
        log_info "Removed prompt configuration from .bashrc"
    fi

    # Remove prompt files
    local prompt_files=(".bash_prompt_functions" ".bash_prompt_config")
    for file in "${prompt_files[@]}"; do
        local full_path="$DEV_HOME/$file"
        if [[ -f "$full_path" ]]; then
            rm -f "$full_path"
            log_info "Removed: $file"
        fi
    done

    log_success "Prompt configuration reset to system defaults"
    log_info "Start a new shell session to see changes"
    return 0
}

# =============================================================================
# Export Functions
# =============================================================================

# Export utility functions for external use
export -f change_prompt_style demo_prompt_styles reset_prompt_config