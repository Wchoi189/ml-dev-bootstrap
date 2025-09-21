#!/bin/bash
# =============================================================================
# SSH Permissions Fix - Integration Tests
# Tests the script end-to-end in realistic scenarios
# =============================================================================

# Script under test
SCRIPT_UNDER_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../utils/fix-ssh-permissions.sh"

# Test setup
setUp() {
    setup_test_env
}

tearDown() {
    cleanup_test_env
}

# Integration test: Create messy permissions and fix them
test_fix_messy_permissions() {
    echo "Testing permission fix on messy SSH directory..."

    # Create test SSH files with wrong permissions
    local private_key="$TEST_SSH_DIR/id_rsa"
    local public_key="$TEST_SSH_DIR/id_rsa.pub"
    local config_file="$TEST_SSH_DIR/config"
    local auth_keys="$TEST_SSH_DIR/authorized_keys"

    # Create files
    echo "-----BEGIN RSA PRIVATE KEY-----" > "$private_key"
    echo "test private key content" >> "$private_key"
    echo "-----END RSA PRIVATE KEY-----" >> "$private_key"

    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhS test@example.com" > "$public_key"

    echo "Host example.com" > "$config_file"
    echo "    User test" >> "$config_file"

    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhS test@example.com" > "$auth_keys"

    # Set wrong permissions (world-readable private key, etc.)
    chmod 777 "$TEST_SSH_DIR"  # Wrong directory permissions
    chmod 644 "$private_key"   # Wrong private key permissions
    chmod 600 "$public_key"    # Wrong public key permissions
    chmod 644 "$config_file"   # Wrong config permissions
    chmod 644 "$auth_keys"     # Wrong auth keys permissions

    # Verify wrong permissions are set
    assert_directory_permissions "777" "$TEST_SSH_DIR" "Directory should start with wrong permissions"
    assert_file_permissions "644" "$private_key" "Private key should start with wrong permissions"

    # Run the fix script
    "$SCRIPT_UNDER_TEST" "$TEST_SSH_DIR" >/dev/null 2>&1

    # Verify permissions are now correct
    assert_directory_permissions "700" "$TEST_SSH_DIR" "Directory should be fixed to 700"
    assert_file_permissions "600" "$private_key" "Private key should be fixed to 600"
    assert_file_permissions "644" "$public_key" "Public key should be fixed to 644"
    assert_file_permissions "600" "$config_file" "Config should be fixed to 600"
    assert_file_permissions "600" "$auth_keys" "Authorized keys should be fixed to 600"
}

# Integration test: Test with missing SSH directory
test_missing_ssh_directory() {
    echo "Testing with missing SSH directory..."

    # Remove the test SSH directory
    rm -rf "$TEST_SSH_DIR"

    # Verify it doesn't exist
    assert_command_fails "test -d '$TEST_SSH_DIR'" "SSH directory should not exist initially"

    # Run the script (should create directory)
    "$SCRIPT_UNDER_TEST" "$TEST_SSH_DIR" >/dev/null 2>&1

    # Verify directory was created with correct permissions
    assert_directory_permissions "700" "$TEST_SSH_DIR" "SSH directory should be created with 700 permissions"
}

# Integration test: Test with empty SSH directory
test_empty_ssh_directory() {
    echo "Testing with empty SSH directory..."

    # SSH directory exists but is empty
    assert_command_succeeds "test -d '$TEST_SSH_DIR'" "SSH directory should exist"

    # Run the script
    "$SCRIPT_UNDER_TEST" "$TEST_SSH_DIR" >/dev/null 2>&1

    # Should still have correct permissions
    assert_directory_permissions "700" "$TEST_SSH_DIR" "Empty SSH directory should maintain 700 permissions"
}

# Integration test: Test with various key types
test_multiple_key_types() {
    echo "Testing with multiple SSH key types..."

    # Create different types of keys
    local rsa_key="$TEST_SSH_DIR/id_rsa"
    local ed25519_key="$TEST_SSH_DIR/id_ed25519"
    local ecdsa_key="$TEST_SSH_DIR/id_ecdsa"
    local rsa_pub="$TEST_SSH_DIR/id_rsa.pub"
    local ed25519_pub="$TEST_SSH_DIR/id_ed25519.pub"
    local ecdsa_pub="$TEST_SSH_DIR/id_ecdsa.pub"

    # Create mock key files (just content, not real keys for speed)
    echo "-----BEGIN RSA PRIVATE KEY-----" > "$rsa_key"
    echo "mock rsa key" >> "$rsa_key"
    echo "-----END RSA PRIVATE KEY-----" >> "$rsa_key"

    echo "-----BEGIN OPENSSH PRIVATE KEY-----" > "$ed25519_key"
    echo "mock ed25519 key" >> "$ed25519_key"
    echo "-----END OPENSSH PRIVATE KEY-----" >> "$ed25519_key"

    echo "-----BEGIN EC PRIVATE KEY-----" > "$ecdsa_key"
    echo "mock ecdsa key" >> "$ecdsa_key"
    echo "-----END EC PRIVATE KEY-----" >> "$ecdsa_key"

    # Create public keys
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhS test@example.com" > "$rsa_pub"
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGmJyRtzmN test@example.com" > "$ed25519_pub"
    echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzd test@example.com" > "$ecdsa_pub"

    # Set wrong permissions
    chmod 644 "$rsa_key" "$ed25519_key" "$ecdsa_key"
    chmod 600 "$rsa_pub" "$ed25519_pub" "$ecdsa_pub"

    # Run the fix script
    "$SCRIPT_UNDER_TEST" "$TEST_SSH_DIR" >/dev/null 2>&1

    # Verify all private keys are 600 and public keys are 644
    assert_file_permissions "600" "$rsa_key" "RSA private key should be 600"
    assert_file_permissions "600" "$ed25519_key" "Ed25519 private key should be 600"
    assert_file_permissions "600" "$ecdsa_key" "ECDSA private key should be 600"
    assert_file_permissions "644" "$rsa_pub" "RSA public key should be 644"
    assert_file_permissions "644" "$ed25519_pub" "Ed25519 public key should be 644"
    assert_file_permissions "644" "$ecdsa_pub" "ECDSA public key should be 644"
}

# Integration test: Test known_hosts handling
test_known_hosts_handling() {
    echo "Testing known_hosts file handling..."

    local known_hosts="$TEST_SSH_DIR/known_hosts"

    # Create known_hosts with wrong permissions
    echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" > "$known_hosts"
    chmod 600 "$known_hosts"  # Wrong permissions for known_hosts

    # Run the fix script
    "$SCRIPT_UNDER_TEST" "$TEST_SSH_DIR" >/dev/null 2>&1

    # Verify known_hosts has correct permissions (644)
    assert_file_permissions "644" "$known_hosts" "known_hosts should be 644"
}

# Run tests
echo "Running Integration Tests for SSH Permissions Fix Script"
echo "======================================================="

setUp
test_fix_messy_permissions
test_missing_ssh_directory
test_empty_ssh_directory
test_multiple_key_types
test_known_hosts_handling
tearDown

echo ""
echo "Integration tests completed."