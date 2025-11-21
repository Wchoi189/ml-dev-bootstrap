#!/bin/bash
# =============================================================================
# Menu and User Interface Module
# Handles all interactive menu functionality and user interface elements
# =============================================================================

# =============================================================================
# Color and Menu Styling Functions
# =============================================================================

# Color helper functions for menu
color_red() { echo -e "\033[0;31m$1\033[0m"; }
color_green() { echo -e "\033[0;32m$1\033[0m"; }
color_yellow() { echo -e "\033[1;33m$1\033[0m"; }
color_blue() { echo -e "\033[0;34m$1\033[0m"; }
color_purple() { echo -e "\033[0;35m$1\033[0m"; }
color_cyan() { echo -e "\033[0;36m$1\033[0m"; }
color_white() { echo -e "\033[1;37m$1\033[0m"; }
color_bold() { echo -e "\033[1m$1\033[0m"; }

# Menu styling functions
menu_header() { echo -e "\033[1;36m$1\033[0m"; }
menu_option() { echo -e "\033[0;32m$1\033[0;33m$2\033[0m"; }
menu_highlight() { echo -e "\033[1;35m$1\033[0m"; }
menu_separator() { echo -e "\033[0;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"; }

# =============================================================================
# Menu Display Functions
# =============================================================================

show_usage() {
    cat << 'EOF'
Development Environment Setup Utility

Usage: $0 [OPTIONS] [MODULES...]

OPTIONS:
    -h, --help          Show this help message
    -a, --all           Run all modules in order
    -m, --menu          Show interactive menu
    -l, --list          List available modules
    -c, --config        Show current configuration
    -s, --switch-user   Switch to development user
    -d, --dry-run       Preview what would be executed
    -v, --verbose       Enable verbose logging
    --verbose-output    Enable verbose logging with detailed output
    --diagnose          Run comprehensive diagnostics
    --update            Update environment components
    --backup            Create environment backup
    --python-version X  Install specific Python version with pyenv
    --progress          Show detailed progress for --all

MODULES:
EOF
    for module in "${MODULE_ORDER[@]}"; do
        printf "    %-12s %s\n" "$module" "$(get_module_description "$module")"
    done

    cat << 'EOF'

EXAMPLES:
    ./setup.sh --all                    # Run all modules
    ./setup.sh --menu                   # Interactive menu
    ./setup.sh system locale user       # Run specific modules
    ./setup.sh --dry-run --all         # Preview all operations

EOF
}

show_config() {
    log_info "Current Configuration:"
    echo "  Username: $USERNAME"
    echo "  User Group: $USER_GROUP"
    echo "  Log Level: $LOG_LEVEL"
    echo "  Script Directory: $SCRIPT_DIR"
    echo "  Config File: $CONFIG_FILE"
}

list_modules() {
    log_info "Available Modules:"
    for module in "${MODULE_ORDER[@]}"; do
        printf "  %-12s %s\n" "$module" "$(get_module_description "$module")"
    done
}

# =============================================================================
# User Management Functions
# =============================================================================

switch_to_dev_user() {
    local dev_user="${1:-${USERNAME:-vscode}}"

    # Check if user exists
    if ! id "$dev_user" >/dev/null 2>&1; then
        log_error "Development user '$dev_user' does not exist. Run the 'user' module first."
        return 1
    fi

    log_info "Switching to development user '$dev_user'..."
    log_info "Setup files are available in multiple locations:"
    log_info "  • ~/setup (symlink in your home directory)"
    log_info "  • /opt/ml-dev-bootstrap (main location)"
    log_info "  • /root/ml-dev-bootstrap (symlink for compatibility)"
    echo
    log_info "After switching, run: cd ~/setup && ./setup.sh --menu"
    echo
    read -p "Press Enter to switch to user '$dev_user' (or Ctrl+C to cancel): "

    # Switch to the user
    log_info "Switching to user '$dev_user'..."
    exec su - "$dev_user"
}

# =============================================================================
# Main Interactive Menu
# =============================================================================

show_user_management_menu() {
    while true; do
        clear
        echo
        menu_separator
        echo "        $(menu_header "👤 USER MANAGEMENT")"
        menu_separator
        echo

        # Check for existing users (filter out system users)
        local existing_users=()
        while IFS=: read -r username _ uid _; do
            # Only include users with UID >= 1000 (regular users) and not system users
            if [[ "$uid" -ge 1000 ]] && [[ "$username" != "nobody" ]] && [[ "$username" != "nogroup" ]] && id "$username" >/dev/null 2>&1; then
                existing_users+=("$username")
            fi
        done < /etc/passwd

        if [[ ${#existing_users[@]} -gt 0 ]]; then
            echo "        $(color_cyan "Existing users:")"
            local i=1
            for user in "${existing_users[@]}"; do
                printf "        $(color_green "%d)") $(color_white "%s")\n" $i "$user"
                ((i++))
            done
            echo
            echo "        $(color_cyan "Options:")"
            echo "        $(menu_option "c)" " Create new user")"
            echo "        $(menu_option "s)" " Switch to existing user")"
            echo "        $(menu_option "b)" " Back to main menu")"
        else
            echo "        $(color_yellow "No existing users found.")"
            echo
            echo "        $(color_cyan "Options:")"
            echo "        $(menu_option "c)" " Create new user")"
            echo "        $(menu_option "b)" " Back to main menu")"
        fi

        echo
        menu_separator
        echo
        echo -n "        $(color_purple "Select option:") "
        read -p "" user_choice
        echo

        case $user_choice in
            c|C)
                create_new_user_workflow
                ;;
            s|S)
                if [[ ${#existing_users[@]} -gt 0 ]]; then
                    switch_to_existing_user "${existing_users[@]}"
                else
                    echo "        $(color_red "No existing users to switch to.")"
                    sleep 2
                fi
                ;;
            b|B)
                return 0
                ;;
            [1-9]|[1-9][0-9])
                if [[ ${#existing_users[@]} -gt 0 ]] && [[ $user_choice -le ${#existing_users[@]} ]]; then
                    local selected_user="${existing_users[$((user_choice - 1))]}"
                    echo "        $(color_blue "Switching to user '$selected_user'...")"
                    echo
                    switch_to_dev_user "$selected_user"
                    return 0
                else
                    echo "        $(color_red "Invalid user selection.")"
                    sleep 2
                fi
                ;;
            *)
                echo "        $(color_red "Invalid option:") $(color_yellow "$user_choice")"
                sleep 2
                ;;
        esac
    done
}

create_new_user_workflow() {
    echo "        $(color_blue "Create New User")"
    echo

    # Ask for username
    local default_username="${USERNAME:-vscode}"
    echo -n "        $(color_cyan "Enter username") $(color_white "[$default_username]"): "
    read -p "" new_username

    if [[ -z "$new_username" ]]; then
        new_username="$default_username"
    fi

    # Validate username
    if [[ ! "$new_username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        echo "        $(color_red "Invalid username. Use only letters, numbers, underscore, and hyphen.")"
        echo
        echo -n "        $(color_purple "Press Enter to continue...")"
        read -p ""
        return 1
    fi

    # Check if user already exists
    if id "$new_username" >/dev/null 2>&1; then
        echo "        $(color_red "User '$new_username' already exists.")"
        echo
        echo -n "        $(color_purple "Press Enter to continue...")"
        read -p ""
        return 1
    fi

    # Ask about password
    echo -n "        $(color_cyan "Create password for user? (y/n) [n]: ")"
    read -p "" create_password

    if [[ "$create_password" =~ ^[Yy]$ ]]; then
        echo "        $(color_yellow "Note: You will be prompted to set the password after user creation.")"
    fi

    echo
    echo "        $(color_blue "Creating user '$new_username'...")"
    echo

    # Temporarily override USERNAME for this session
    export USERNAME="$new_username"

    # Create the user
    if execute_module "user"; then
        echo
        echo "        $(color_green "User '$new_username' created successfully!")"

        # Handle password creation if requested
        if [[ "$create_password" =~ ^[Yy]$ ]]; then
            echo
            echo "        $(color_blue "Setting password for '$new_username'...")"
            if [[ "${DRY_RUN:-false}" != "true" ]]; then
                passwd "$new_username"
            else
                echo "        $(color_yellow "[DRY RUN] Would prompt for password")"
            fi
        fi

        echo
        echo "        $(color_blue "Switching to user '$new_username'...")"
        echo
        switch_to_dev_user "$new_username"
        return 0
    else
        echo
        echo "        $(color_red "Failed to create user '$new_username'.")"
        echo
        echo -n "        $(color_purple "Press Enter to continue...")"
        read -p ""
        return 1
    fi
}

switch_to_existing_user() {
    local existing_users=("$@")

    echo "        $(color_blue "Switch to Existing User")"
    echo
    echo "        $(color_cyan "Available users:")"
    local i=1
    for user in "${existing_users[@]}"; do
        printf "        $(color_green "%d)") $(color_white "%s")\n" $i "$user"
        ((i++))
    done
    echo
    echo -n "        $(color_purple "Select user (1-${#existing_users[@]}) or enter username: ")"
    read -p "" user_selection

    local selected_user=""

    # Check if it's a number
    if [[ "$user_selection" =~ ^[0-9]+$ ]] && [[ $user_selection -le ${#existing_users[@]} ]]; then
        selected_user="${existing_users[$((user_selection - 1))]}"
    else
        # Check if it's a valid username
        for user in "${existing_users[@]}"; do
            if [[ "$user" == "$user_selection" ]]; then
                selected_user="$user"
                break
            fi
        done
    fi

    if [[ -n "$selected_user" ]]; then
        echo "        $(color_blue "Switching to user '$selected_user'...")"
        echo
        switch_to_dev_user "$selected_user"
        return 0
    else
        echo "        $(color_red "Invalid user selection.")"
        echo
        echo -n "        $(color_purple "Press Enter to continue...")"
        read -p ""
        return 1
    fi
}

show_menu() {
    while true; do
        clear
        echo
        menu_separator
        echo "        $(menu_header "🚀 DEVELOPMENT ENVIRONMENT SETUP")"
        menu_separator
        echo
        echo "        $(color_cyan "Available Modules:")"
        echo
        local i=1
        for module in "${MODULE_ORDER[@]}"; do
            local desc="$(get_module_description "$module")"
            printf "        $(color_green "%d)") $(color_yellow "%-12s") $(color_white "%s")\n" $i "$module" "$desc"
            ((i++))
        done
        echo
        menu_separator
        echo
        echo "        $(color_cyan "Quick Actions:")"
        echo "        $(menu_option "a)" " Run all modules (skips envmgr and SSH by default)")"
        echo "        $(menu_option "s)" " Configure APT sources")"
        echo "        $(menu_option "r)" " User management (create/switch)")"
        echo "        $(menu_option "e)" " Run environment manager(s) (multi-select)")"
        echo "        $(menu_option "p)" " Fix SSH permissions")"
        echo "        $(menu_option "g)" " Install/configure GitHub CLI (gh)")"
        echo "        $(menu_option "c)" " Show configuration")"
        echo "        $(menu_option "q)" " Quit")"
        echo
        menu_separator
        echo
        echo -n "        $(color_purple "Select option:") "
        read -p "" choice
        echo
        case $choice in
            [1-7])
                local module_index=$((choice - 1))
                local selected_module="${MODULE_ORDER[$module_index]}"
                echo "        $(color_blue "Executing module:") $(color_yellow "$selected_module")"
                echo
                execute_module "$selected_module"
                echo
                echo -n "        $(color_purple "Press Enter to continue...")"
                read -p ""
                ;;
            a|A)
                echo "        $(color_blue "Running all modules (skipping envmgr and ssh)...")"
                echo
                # Run all except envmgr and ssh
                for m in "${MODULE_ORDER[@]}"; do
                    [[ "$m" == "envmgr" ]] && continue
                    [[ "$m" == "ssh" ]] && continue
                    execute_module "$m"
                done
                echo
                echo -n "        $(color_purple "Press Enter to continue...")"
                read -p ""
                ;;
            s|S)
                echo "        $(color_blue "Configuring APT sources...")"
                echo
                execute_module "sources"
                echo
                echo -n "        $(color_purple "Press Enter to continue...")"
                read -p ""
                ;;
            r|R)
                show_user_management_menu
                ;;
            e|E)
                echo "        $(color_cyan "Select environment managers to install (comma-separated, e.g. 1,2):")"
                echo
                local env_opts=("conda" "micromamba" "pyenv" "poetry" "pipenv" "uv")
                for idx in "${!env_opts[@]}"; do
                    printf "        $(color_green "%d)") $(color_white "%s")\n" $((idx+1)) "${env_opts[$idx]}"
                done
                echo
                echo -n "        $(color_purple "Your choice:") "
                read -p "" env_choice
                echo
                IFS=',' read -ra env_indices <<< "$env_choice"
                export SELECTED_ENVMGRS=""
                local pyenv_selected=false
                for idx in "${env_indices[@]}"; do
                    idx_trimmed="$(echo $idx | xargs)"
                    if [[ $idx_trimmed =~ ^[1-6]$ ]]; then
                        local env_name="${env_opts[$((idx_trimmed-1))]}"
                        export SELECTED_ENVMGRS+="$env_name,"
                        if [[ "$env_name" == "pyenv" ]]; then
                            pyenv_selected=true
                            export INSTALL_PYENV=yes
                        fi
                    fi
                done
                # Trim any trailing comma to avoid empty entries
                SELECTED_ENVMGRS="${SELECTED_ENVMGRS%,}"
                if [[ -z "$SELECTED_ENVMGRS" ]]; then
                    echo "        $(color_red "No valid selections made.")"
                    echo -n "        $(color_purple "Press Enter to continue...")"
                    read -p ""
                    continue
                fi
                if [[ "$pyenv_selected" == true ]]; then
                    echo -n "        $(color_cyan "Enter Python version to install with pyenv (leave blank for default):") "
                    read -p "" pyver
                    if [[ -n "$pyver" ]]; then
                        export PYENV_PYTHON_VERSION="$pyver"
                        echo "        $(color_blue "Will install Python version:") $(color_yellow "$pyver") $(color_blue "with pyenv.")"
                    fi
                fi
                echo "        $(color_blue "Executing environment manager setup...")"
                echo
                execute_module "envmgr"
                echo
                echo -n "        $(color_purple "Press Enter to continue...")"
                read -p ""
                ;;
            p|P)
                echo "        $(color_blue "Fixing SSH permissions...")"
                echo
                local utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd "utils" && pwd)"
                if [[ -x "$utils_dir/fix-ssh-permissions.sh" ]]; then
                    "$utils_dir/fix-ssh-permissions.sh"
                else
                    echo "        $(color_red "SSH permissions fix script not found at:") $(color_yellow "$utils_dir/fix-ssh-permissions.sh")"
                fi
                echo
                echo -n "        $(color_purple "Press Enter to continue...")"
                read -p ""
                ;;
            g|G)
                echo "        $(color_blue "Installing and configuring GitHub CLI...")"
                echo
                execute_module "ghcli"
                echo
                echo -n "        $(color_purple "Press Enter to continue...")"
                read -p ""
                ;;
            c|C)
                echo "        $(color_blue "Current Configuration:")"
                echo
                show_config
                echo
                echo -n "        $(color_purple "Press Enter to continue...")"
                read -p ""
                ;;
            q|Q)
                echo "        $(color_green "Goodbye! 👋")"
                echo
                exit 0
                ;;
            *)
                echo "        $(color_red "Invalid option:") $(color_yellow "$choice")"
                echo "        $(color_cyan "Please select a valid option from the menu.")"
                sleep 2
                ;;
        esac
    done
}
