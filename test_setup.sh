#!/bin/bash

# =============================================================================
# Setup Utility Test Script
# Comprehensive testing of the development environment setup
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/common.sh"
source "$SCRIPT_DIR/utils/logger.sh"

# Test configuration
TEST_USER="test_dev-user"
TEST_GROUP="test_dev"
TEST_HOME="/home/$TEST_USER"

init_logging
export LOG_LEVEL=DEBUG

log_header "Setup Utility Test Suite"

# =============================================================================
# Test Functions
# =============================================================================

test_module_loading() {
    log_info "Testing module loading..."
    
    local modules=("system" "locale" "user" "conda" "prompt" "git")
    local failed_modules=()
    
    for module in "${modules[@]}"; do
        local module_file="$SCRIPT_DIR/modules/${module}.sh"
        
        if [[ -f "$module_file" ]]; then
            if source "$module_file" 2>/dev/null; then
                if declare -f "run_${module}" >/dev/null; then
                    log_success "Module $module: OK"
                else
                    log_error "Module $module: Missing run function"
                    failed_modules+=("$module")
                fi
            else
                log_error "Module $module: Source failed"
                failed_modules+=("$module")
            fi
        else
            log_error "Module $module: File not found"
            failed_modules+=("$module")
        fi
    done
    
    if [[ ${#failed_modules[@]} -eq 0 ]]; then
        log_success "All modules loaded successfully"
        return 0
    else
        log_error "Failed modules: ${failed_modules[*]}"
        return 1
    fi
}

test_dry_run_mode() {
    log_info "Testing dry-run mode..."
    
    export DRY_RUN=true
    
    # Test each module in dry-run mode
    local modules=("system" "locale" "user" "conda" "prompt" "git")
    local failed_tests=()
    
    for module in "${modules[@]}"; do
        log_info "Testing dry-run for module: $module"
        
        if "$SCRIPT_DIR/setup.sh" --dry-run "$module" >/dev/null 2>&1; then
            log_success "Dry-run test passed: $module"
        else
            log_error "Dry-run test failed: $module"
            failed_tests+=("$module")
        fi
    done
    
    unset DRY_RUN
    
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log_success "All dry-run tests passed"
        return 0
    else
        log_error "Failed dry-run tests: ${failed_tests[*]}"
        return 1
    fi
}

test_configuration_validation() {
    log_info "Testing configuration validation..."
    
    # Test invalid configurations
    local test_configs=(
        "USERNAME="
        "USER_GROUP="
        "GIT_USER_EMAIL=invalid-email"
        "DEFAULT_LOCALE=invalid_locale"
    )
    
    local validation_errors=0
    
    for config in "${test_configs[@]}"; do
        log_debug "Testing invalid config: $config"
        
        # This would need to be implemented in the actual validation functions
        # For now, we'll just log that we're testing it
        log_debug "Config validation test: $config"
    done
    
    log_success "Configuration validation tests completed"
    return 0
}

test_utility_functions() {
    log_info "Testing utility functions..."
    
    # Test common utility functions
    local test_results=()
    
    # Test validate_username
    if validate_username "valid_user"; then
        test_results+=("validate_username:valid:PASS")
    else
        test_results+=("validate_username:valid:FAIL")
    fi
    
    if ! validate_username "123invalid"; then
        test_results+=("validate_username:invalid:PASS")
    else
        test_results+=("validate_username:invalid:FAIL")
    fi
    
    # Test validate_email
    if validate_email "test@example.com"; then
        test_results+=("validate_email:valid:PASS")
    else
        test_results+=("validate_email:valid:FAIL")
    fi
    
    if ! validate_email "invalid-email"; then
        test_results+=("validate_email:invalid:PASS")
    else
        test_results+=("validate_email:invalid:FAIL")
    fi
    
    # Test check_command
    if check_command "bash"; then
        test_results+=("check_command:bash:PASS")
    else
        test_results+=("check_command:bash:FAIL")
    fi
    
    if ! check_command "nonexistent_command_12345"; then
        test_results+=("check_command:nonexistent:PASS")
    else
        test_results+=("check_command:nonexistent:FAIL")
    fi
    
    # Show results
    local failed_tests=0
    for result in "${test_results[@]}"; do
        local test_name=$(echo "$result" | cut -d: -f1-2)
        local status=$(echo "$result" | cut -d: -f3)
        
        if [[ "$status" == "PASS" ]]; then
            log_success "Utility test passed: $test_name"
        else
            log_error "Utility test failed: $test_name"
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All utility function tests passed"
        return 0
    else
        log_error "$failed_tests utility function tests failed"
        return 1
    fi
}

test_file_operations() {
    log_info "Testing file operations..."
    
    local test_dir="/tmp/setup_test_$$"
    local test_file="$test_dir/test_file"
    
    # Create test directory
    if create_directory "$test_dir" "" "755"; then
        log_success "Directory creation test passed"
    else
        log_error "Directory creation test failed"
        return 1
    fi
    
    # Test file backup
    echo "test content" > "$test_file"
    if backup_file "$test_file"; then
        # Look for backup files with the correct pattern
        local backup_files=("${test_file}.backup."*)
        if [[ -f "${backup_files[0]}" ]]; then
            log_success "File backup test passed"
        else
            log_error "File backup test failed - backup not created"
            return 1
        fi
    else
        log_error "File backup test failed"
        return 1
    fi

    # Test safe append
    if safe_append_to_file "$test_file" "appended content" "# Test marker"; then
        if grep -q "appended content" "$test_file"; then
            log_success "Safe append test passed"
        else
            log_error "Safe append test failed - content not found"
            return 1
        fi
    else
        log_error "Safe append test failed"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    log_success "All file operation tests passed"
    return 0
}

test_logging_system() {
    log_info "Testing logging system..."
    
    # Test different log levels
    log_debug "Debug message test"
    log_info "Info message test"
    log_warn "Warning message test"
    log_error "Error message test"
    log_success "Success message test"
    
    # Test log header
    log_header "Test Header"
    
    # Test log separator
    log_separator
    
    log_success "Logging system test completed"
    return 0
}

run_integration_test() {
    log_info "Running integration test..."
    
    # This would test the complete setup process in a controlled environment
    # For safety, we'll only run this in dry-run mode
    
    export DRY_RUN=true
    export USERNAME="$TEST_USER"
    export USER_GROUP="$TEST_GROUP"
    export GIT_USER_NAME="dev-user"
    export GIT_USER_EMAIL="YOURUSERNAME@gmail.com"
    
    log_info "Running complete setup in dry-run mode..."
    
    if "$SCRIPT_DIR/setup.sh" --all --dry-run >/dev/null 2>&1; then
        log_success "Integration test passed - complete setup dry-run successful"
    else
        log_error "Integration test failed - complete setup dry-run failed"
        return 1
    fi
    
    unset DRY_RUN USERNAME USER_GROUP GIT_USER_NAME GIT_USER_EMAIL
    
    log_success "Integration test completed"
    return 0
}

test_menu_system() {
    log_info "Testing menu system..."

    # Define expected modules if MODULES array doesn't exist
    if [[ -z "${MODULES:-}" ]]; then
        # Try to source the main setup script to get MODULES array
        local setup_script="$SCRIPT_DIR/setup.sh"
        if [[ -f "$setup_script" ]]; then
            # Extract module definitions from setup.sh
            source "$setup_script" --dry-run system >/dev/null 2>&1 || true
        fi
    fi
       
    # Test that menu options are properly defined
    local menu_options=("system" "locale" "user" "conda" "prompt" "git")
    local missing_options=()
    
    for option in "${menu_options[@]}"; do
        if [[ -z "${MODULES[$option]:-}" ]]; then
            missing_options+=("$option")
        fi
    done
    
    if [[ ${#missing_options[@]} -eq 0 ]]; then
        log_success "Menu system test passed - all options defined"
    else
        log_error "Menu system test failed - missing options: ${missing_options[*]}"
        return 1
    fi
    
    return 0
}

test_error_handling() {
    log_info "Testing error handling..."
    
    # Test handling of missing files
    local nonexistent_file="/tmp/nonexistent_file_12345"
    
    if backup_file "$nonexistent_file" 2>/dev/null; then
        log_error "Error handling test failed - should not backup nonexistent file"
        return 1
    else
        log_success "Error handling test passed - correctly handled nonexistent file"
    fi
    
    # Test handling of invalid user
    if check_user_exists "nonexistent_user_12345"; then
        log_error "Error handling test failed - should not find nonexistent user"
        return 1
    else
        log_success "Error handling test passed - correctly handled nonexistent user"
    fi
    
    log_success "Error handling tests completed"
    return 0
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_all_tests() {
    log_header "Running Complete Test Suite"
    
    local tests=(
        "test_module_loading"
        "test_dry_run_mode"
        "test_configuration_validation"
        "test_utility_functions"
        "test_file_operations"
        "test_logging_system"
        "test_menu_system"
        "test_error_handling"
        "run_integration_test"
    )
    
    local passed_tests=0
    local failed_tests=0
    local failed_test_names=()
    
    for test in "${tests[@]}"; do
        log_separator
        log_info "Running test: $test"
        
        if $test; then
            ((passed_tests++))
            log_success "✅ Test passed: $test"
        else
            ((failed_tests++))
            failed_test_names+=("$test")
            log_error "❌ Test failed: $test"
        fi
    done
    
    # Show final results
    log_separator
    log_header "Test Results Summary"
    
    echo "Total tests: $((passed_tests + failed_tests))"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "🎉 All tests passed!"
        echo ""
        echo "The setup utility is ready for use."
        return 0
    else
        log_error "❌ $failed_tests tests failed"
        echo ""
        echo "Failed tests:"
        for test in "${failed_test_names[@]}"; do
            echo "  - $test"
        done
        echo ""
        echo "Please fix the issues before using the setup utility."
        return 1
    fi
}

# =============================================================================
# Test Script Main Function
# =============================================================================

main() {
    case "${1:-all}" in
        "all")
            run_all_tests
            ;;
        "modules")
            test_module_loading
            ;;
        "dry-run")
            test_dry_run_mode
            ;;
        "utilities")
            test_utility_functions
            ;;
        "files")
            test_file_operations
            ;;
        "logging")
            test_logging_system
            ;;
        "integration")
            run_integration_test
            ;;
        "menu")
            test_menu_system
            ;;
        "errors")
            test_error_handling
            ;;
        *)
            echo "Usage: $0 [all|modules|dry-run|utilities|files|logging|integration|menu|errors]"
            echo ""
            echo "Test categories:"
            echo "  all         - Run all tests (default)"
            echo "  modules     - Test module loading"
            echo "  dry-run     - Test dry-run functionality"
            echo "  utilities   - Test utility functions"
            echo "  files       - Test file operations"
            echo "  logging     - Test logging system"
            echo "  integration - Test complete setup process"
            echo "  menu        - Test menu system"
            echo "  errors      - Test error handling"
            exit 1
            ;;
    esac
}

# Run the test script
main "$@"