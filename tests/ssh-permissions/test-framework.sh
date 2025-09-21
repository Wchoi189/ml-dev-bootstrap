#!/bin/bash
# =============================================================================
# SSH Permissions Fix - Test Framework
# Simple bash-based testing framework for CI environments
# =============================================================================

set -euo pipefail

# Test framework variables
TEST_PASSED=0
TEST_FAILED=0
TESTS_RUN=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    ((TESTS_RUN++))
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓ PASS${NC} $message"
        ((TEST_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        ((TEST_FAILED++))
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-}"

    ((TESTS_RUN++))
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ PASS${NC} $message"
        ((TEST_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} $message"
        echo -e "  File does not exist: '$file'"
        ((TEST_FAILED++))
    fi
}

assert_file_permissions() {
    local expected_perms="$1"
    local file="$2"
    local message="${3:-}"

    ((TESTS_RUN++))
    if [[ -f "$file" ]]; then
        local actual_perms
        actual_perms=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%A' "$file" 2>/dev/null || echo "unknown")
        if [[ "$actual_perms" == "$expected_perms" ]]; then
            echo -e "${GREEN}✓ PASS${NC} $message"
            ((TEST_PASSED++))
        else
            echo -e "${RED}✗ FAIL${NC} $message"
            echo -e "  Expected permissions: '$expected_perms'"
            echo -e "  Actual permissions:   '$actual_perms'"
            ((TEST_FAILED++))
        fi
    else
        echo -e "${RED}✗ FAIL${NC} $message"
        echo -e "  File does not exist: '$file'"
        ((TEST_FAILED++))
    fi
}

assert_directory_permissions() {
    local expected_perms="$1"
    local dir="$2"
    local message="${3:-}"

    ((TESTS_RUN++))
    if [[ -d "$dir" ]]; then
        local actual_perms
        actual_perms=$(stat -c '%a' "$dir" 2>/dev/null || stat -f '%A' "$dir" 2>/dev/null || echo "unknown")
        if [[ "$actual_perms" == "$expected_perms" ]]; then
            echo -e "${GREEN}✓ PASS${NC} $message"
            ((TEST_PASSED++))
        else
            echo -e "${RED}✗ FAIL${NC} $message"
            echo -e "  Expected permissions: '$expected_perms'"
            echo -e "  Actual permissions:   '$actual_perms'"
            ((TEST_FAILED++))
        fi
    else
        echo -e "${RED}✗ FAIL${NC} $message"
        echo -e "  Directory does not exist: '$dir'"
        ((TEST_FAILED++))
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-}"

    ((TESTS_RUN++))
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC} $message"
        ((TEST_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} $message"
        echo -e "  Command failed: '$command'"
        ((TEST_FAILED++))
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-}"

    ((TESTS_RUN++))
    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC} $message"
        ((TEST_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} $message"
        echo -e "  Command should have failed: '$command'"
        ((TEST_FAILED++))
    fi
}

# Test setup/cleanup functions
setup_test_env() {
    # Create a temporary test directory
    TEST_TMP_DIR=$(mktemp -d)
    export TEST_TMP_DIR

    # Create test SSH directory structure
    TEST_SSH_DIR="$TEST_TMP_DIR/.ssh"
    mkdir -p "$TEST_SSH_DIR"

    export TEST_SSH_DIR
}

cleanup_test_env() {
    if [[ -n "${TEST_TMP_DIR:-}" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# Test runner
run_test_suite() {
    local test_file="$1"
    local test_name="${2:-$(basename "$test_file" .sh)}"

    echo ""
    echo -e "${BLUE}Running test suite: $test_name${NC}"
    echo -e "${BLUE}$(printf '%.0s=' {1..50})${NC}"
    echo ""

    # Source the test file
    if [[ -f "$test_file" ]]; then
        source "$test_file"
    else
        echo -e "${RED}Test file not found: $test_file${NC}"
        return 1
    fi
}

# Print test results
print_test_results() {
    echo ""
    echo -e "${BLUE}$(printf '%.0s=' {1..50})${NC}"
    echo -e "${BLUE}Test Results${NC}"
    echo -e "${BLUE}$(printf '%.0s=' {1..50})${NC}"
    echo ""

    if [[ $TEST_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
        echo -e "Tests run: $TESTS_RUN"
        echo -e "Passed: $TEST_PASSED"
        echo -e "Failed: $TEST_FAILED"
        return 0
    else
        echo -e "${RED}Some tests failed! ✗${NC}"
        echo -e "Tests run: $TESTS_RUN"
        echo -e "Passed: $TEST_PASSED"
        echo -e "Failed: $TEST_FAILED"
        return 1
    fi
}

# Main test runner
run_all_tests() {
    local test_dir="${1:-tests/ssh-permissions}"
    local exit_code=0

    echo -e "${BLUE}SSH Permissions Fix - Test Suite${NC}"
    echo -e "${BLUE}$(printf '%.0s=' {1..50})${NC}"

    # Find and run all test files
    if [[ -d "$test_dir" ]]; then
        for test_file in "$test_dir"/*.sh; do
            if [[ -f "$test_file" ]] && [[ "$(basename "$test_file")" != "test-framework.sh" ]]; then
                if ! run_test_suite "$test_file"; then
                    exit_code=1
                fi
            fi
        done
    else
        echo -e "${RED}Test directory not found: $test_dir${NC}"
        exit_code=1
    fi

    print_test_results
    return $exit_code
}

# Export functions for use in test files
export -f assert_equals
export -f assert_file_exists
export -f assert_file_permissions
export -f assert_directory_permissions
export -f assert_command_succeeds
export -f assert_command_fails
export -f setup_test_env
export -f cleanup_test_env

# If this script is run directly, run all tests
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_all_tests "$@"
fi