#!/bin/bash

# =============================================================================
# Logging System
# Provides structured logging with different levels and colors
# =============================================================================

# Log levels
declare -r LOG_LEVEL_DEBUG=0
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_WARN=2
declare -r LOG_LEVEL_ERROR=3
declare -r LOG_LEVEL_SUCCESS=4

# Color codes
declare -r COLOR_RED='\033[0;31m'
declare -r COLOR_GREEN='\033[0;32m'
declare -r COLOR_YELLOW='\033[1;33m'
declare -r COLOR_BLUE='\033[0;34m'
declare -r COLOR_PURPLE='\033[0;35m'
declare -r COLOR_CYAN='\033[0;36m'
declare -r COLOR_WHITE='\033[1;37m'
declare -r COLOR_RESET='\033[0m'

# Icons
declare -r ICON_SUCCESS="✅"
declare -r ICON_ERROR="❌"
declare -r ICON_WARN="⚠️ "
declare -r ICON_INFO="ℹ️ "
declare -r ICON_DEBUG="🔍"

# =============================================================================
# Logging Configuration
# =============================================================================

init_logging() {
    # Set default log level if not set
    case "${LOG_LEVEL:-INFO}" in
        DEBUG) export LOG_LEVEL_NUM=$LOG_LEVEL_DEBUG ;;
        INFO)  export LOG_LEVEL_NUM=$LOG_LEVEL_INFO ;;
        WARN)  export LOG_LEVEL_NUM=$LOG_LEVEL_WARN ;;
        ERROR) export LOG_LEVEL_NUM=$LOG_LEVEL_ERROR ;;
        *) export LOG_LEVEL_NUM=$LOG_LEVEL_INFO ;;
    esac
    
    # Create log file if specified and ensure it's writable.
    # If the requested path isn't writable, try a fallback path under /tmp.
    LOG_FILE_WRITABLE=false
    if [[ -n "${LOG_FILE:-}" ]]; then
        if touch "$LOG_FILE" 2>/dev/null && [[ -w "$LOG_FILE" ]]; then
            LOG_FILE_WRITABLE=true
        else
            # try to fix permissions on an existing file
            if [[ -f "$LOG_FILE" ]]; then
                chmod u+rw "$LOG_FILE" >/dev/null 2>&1 || true
            fi

            if touch "$LOG_FILE" 2>/dev/null && [[ -w "$LOG_FILE" ]]; then
                LOG_FILE_WRITABLE=true
            else
                # fallback to a tmp file in /tmp
                local base_name
                base_name="$(basename "$LOG_FILE")"
                local fallback="/tmp/${base_name:-setup-utility}.${$}.log"
                if touch "$fallback" 2>/dev/null && [[ -w "$fallback" ]]; then
                    echo "Warning: Cannot create or write to log file: $LOG_FILE; using fallback: $fallback" >&2
                    export LOG_FILE="$fallback"
                    LOG_FILE_WRITABLE=true
                else
                    echo "Warning: Cannot create log file: $LOG_FILE and fallback also failed; disabling file logging" >&2
                    unset LOG_FILE
                    LOG_FILE_WRITABLE=false
                fi
            fi
        fi
    fi
    
    log_debug "Logging initialized with level: ${LOG_LEVEL:-INFO}"
}

# =============================================================================
# Core Logging Functions
# =============================================================================

_log() {
    local level="$1"
    local level_num="$2"
    local color="$3"
    local icon="$4"
    local message="$5"
    
    # Check if we should log this level
    if [[ $level_num -lt ${LOG_LEVEL_NUM:-$LOG_LEVEL_INFO} ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local formatted_message
    
    # Format message with color and icon for terminal
    if [[ -t 1 ]]; then  # Check if stdout is a terminal
        formatted_message="${color}${icon} [$level] $message${COLOR_RESET}"
    else
        formatted_message="[$level] $message"
    fi
    
    # Output to terminal
    echo -e "$formatted_message" >&2
    
    # Output to log file if specified and writable
    if [[ -n "${LOG_FILE:-}" && "${LOG_FILE_WRITABLE:-false}" == "true" && -w "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_debug() {
    _log "DEBUG" $LOG_LEVEL_DEBUG "$COLOR_PURPLE" "$ICON_DEBUG" "$*"
}

log_info() {
    _log "INFO" $LOG_LEVEL_INFO "$COLOR_BLUE" "$ICON_INFO" "$*"
}

log_warn() {
    _log "WARN" $LOG_LEVEL_WARN "$COLOR_YELLOW" "$ICON_WARN" "$*"
}

log_error() {
    _log "ERROR" $LOG_LEVEL_ERROR "$COLOR_RED" "$ICON_ERROR" "$*"
}

log_success() {
    _log "SUCCESS" $LOG_LEVEL_SUCCESS "$COLOR_GREEN" "$ICON_SUCCESS" "$*"
}

# =============================================================================
# Special Logging Functions
# =============================================================================

log_header() {
    local message="$1"
    local border_char="${2:-=}"
    local border_length=60
    
    local border=$(printf "%*s" $border_length | tr ' ' "$border_char")
    
    echo -e "\n${COLOR_CYAN}$border${COLOR_RESET}" >&2
    echo -e "${COLOR_CYAN}$message${COLOR_RESET}" >&2
    echo -e "${COLOR_CYAN}$border${COLOR_RESET}\n" >&2
    
    if [[ -n "${LOG_FILE:-}" && "${LOG_FILE_WRITABLE:-false}" == "true" && -w "$LOG_FILE" ]]; then
        echo "" >> "$LOG_FILE" 2>/dev/null || true
        echo "$border" >> "$LOG_FILE" 2>/dev/null || true
        echo "$message" >> "$LOG_FILE" 2>/dev/null || true
        echo "$border" >> "$LOG_FILE" 2>/dev/null || true
        echo "" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_step() {
    local step_num="$1"
    local total_steps="$2"
    local description="$3"
    
    local message="Step $step_num/$total_steps: $description"
    log_header "$message" "-"
}

log_command() {
    local command="$1"
    log_debug "Executing: $command"
    
    if [[ -n "${LOG_FILE:-}" && "${LOG_FILE_WRITABLE:-false}" == "true" && -w "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [COMMAND] $command" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_result() {
    local exit_code="$1"
    local success_msg="${2:-Operation completed successfully}"
    local error_msg="${3:-Operation failed}"
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$success_msg"
    else
        log_error "$error_msg (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# =============================================================================
# Progress Logging
# =============================================================================

log_progress_start() {
    local task="$1"
    echo -n "${COLOR_BLUE}${ICON_INFO} $task... ${COLOR_RESET}" >&2
}

log_progress_end() {
    local success="${1:-true}"
    
    if [[ "$success" == "true" ]]; then
        echo -e "${COLOR_GREEN}Done${COLOR_RESET}" >&2
    else
        echo -e "${COLOR_RED}Failed${COLOR_RESET}" >&2
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

log_separator() {
    echo -e "${COLOR_CYAN}$(printf '%*s' 60 | tr ' ' '-')${COLOR_RESET}" >&2
}

log_blank_line() {
    echo "" >&2
}
# Set log file permissions securely
set_log_permissions() {
    if [[ -n "${LOG_FILE:-}" ]] && [[ -f "$LOG_FILE" ]] && [[ "${LOG_FILE_WRITABLE:-false}" == "true" ]]; then
        chmod 640 "$LOG_FILE" 2>/dev/null || true
        log_debug "Set log file permissions: $LOG_FILE"
    fi
}

# =============================================================================
# Log Analysis Functions
# =============================================================================

show_log_summary() {
    if [[ -z "${LOG_FILE:-}" ]] || [[ ! -f "$LOG_FILE" ]] || [[ ! -r "$LOG_FILE" ]]; then
        log_warn "No log file available for summary"
        return 1
    fi
    
    local total_lines=$(wc -l < "$LOG_FILE")
    local error_count=$(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo "0")
    local warn_count=$(grep -c "\[WARN\]" "$LOG_FILE" 2>/dev/null || echo "0")
    local success_count=$(grep -c "\[SUCCESS\]" "$LOG_FILE" 2>/dev/null || echo "0")
    
    log_header "Log Summary"
    echo "  Log file: $LOG_FILE"
    echo "  Total entries: $total_lines"
    echo "  Errors: $error_count"
    echo "  Warnings: $warn_count"
    echo "  Successes: $success_count"
    
    if [[ $error_count -gt 0 ]]; then
        echo ""
        echo "Recent errors:"
        grep "\[ERROR\]" "$LOG_FILE" | tail -3 | sed 's/^/  /'
    fi
}

# =============================================================================
# Export functions for use in other scripts
# =============================================================================

# Make logging functions available to sourced scripts
export -f log_debug log_info log_warn log_error log_success
export -f log_header log_step log_command log_result
export -f log_progress_start log_progress_end log_separator log_blank_line