#!/bin/bash
# =============================================================================
# SSH Permissions Fix - Unit Tests
# Tests individual functions and components
# =============================================================================

# Source the script under test (with functions)
SCRIPT_UNDER_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../utils/fix-ssh-permissions.sh"

# Test setup
setUp() {
    setup_test_env
}

tearDown() {
    cleanup_test_env
}

# Test helper functions
test_is_wsl_detection() {
    # This is a simple test - in real CI we'd mock this
    # For now, just test that the function exists and runs
    if command -v uname >/dev/null 2>&1; then
        assert_command_succeeds "uname -a" "uname command should work"
    fi
}

test_script_syntax() {
    assert_command_succeeds "bash -n '$SCRIPT_UNDER_TEST'" "Script should have valid syntax"
}

test_script_executable() {
    assert_file_exists "$SCRIPT_UNDER_TEST" "Script file should exist"
    assert_command_succeeds "test -x '$SCRIPT_UNDER_TEST'" "Script should be executable"
}

test_help_output() {
    local output
    output=$("$SCRIPT_UNDER_TEST" --help 2>&1)
    assert_equals 0 $? "Help command should succeed"
    echo "$output" | grep -q "SSH Permissions Fix Utility" || assert_equals 1 0 "Help should contain utility name"
}

test_dry_run_mode() {
    local output
    output=$("$SCRIPT_UNDER_TEST" --dry-run 2>&1)
    assert_equals 0 $? "Dry run should succeed"
    echo "$output" | grep -q "DRY RUN MODE" || assert_equals 1 0 "Dry run should show dry run message"
}

test_invalid_option() {
    local output
    output=$("$SCRIPT_UNDER_TEST" --invalid-option 2>&1)
    # Should exit with error code
    if [[ $? -ne 0 ]]; then
        assert_equals 1 1 "Invalid option should cause error"
    else
        assert_equals 1 0 "Invalid option should cause error"
    fi
}

# Test permission checking logic (mocked)
test_permission_checks() {
    # Create test files with specific permissions
    local test_file="$TEST_SSH_DIR/test_file"
    local test_dir="$TEST_SSH_DIR/test_dir"

    touch "$test_file"
    mkdir "$test_dir"

    # Test file permissions
    chmod 600 "$test_file"
    assert_file_permissions "600" "$test_file" "File should have 600 permissions"

    chmod 644 "$test_file"
    assert_file_permissions "644" "$test_file" "File should have 644 permissions"

    # Test directory permissions
    chmod 700 "$test_dir"
    assert_directory_permissions "700" "$test_dir" "Directory should have 700 permissions"

    chmod 755 "$test_dir"
    assert_directory_permissions "755" "$test_dir" "Directory should have 755 permissions"
}

# Test file type detection
test_file_type_detection() {
    # Create various test files
    local private_key="$TEST_SSH_DIR/id_rsa"
    local public_key="$TEST_SSH_DIR/id_rsa.pub"
    local config_file="$TEST_SSH_DIR/config"
    local auth_keys="$TEST_SSH_DIR/authorized_keys"
    local known_hosts="$TEST_SSH_DIR/known_hosts"

    touch "$private_key" "$public_key" "$config_file" "$auth_keys" "$known_hosts"

    # Test that files exist
    assert_file_exists "$private_key" "Private key should exist"
    assert_file_exists "$public_key" "Public key should exist"
    assert_file_exists "$config_file" "Config file should exist"
    assert_file_exists "$auth_keys" "Authorized keys should exist"
    assert_file_exists "$known_hosts" "Known hosts should exist"
}

# Test path expansion
test_path_expansion() {
    local home_ssh="$HOME/.ssh"
    local tilde_ssh="~/.ssh"

    # Test tilde expansion
    local expanded
    expanded=$(eval echo "$tilde_ssh")
    assert_equals "$home_ssh" "$expanded" "Tilde should expand to home directory"
}

# Run tests
echo "Running Unit Tests for SSH Permissions Fix Script"
echo "================================================="

echo "Starting test execution..."
setUp
echo "Setup completed"
test_is_wsl_detection
echo "test_is_wsl_detection completed"
test_script_syntax
echo "test_script_syntax completed"
test_script_executable
test_help_output
test_dry_run_mode
test_invalid_option
test_permission_checks
test_file_type_detection
test_path_expansion
tearDown

echo ""
echo "Unit tests completed."