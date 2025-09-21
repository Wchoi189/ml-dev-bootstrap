#!/bin/bash
# =============================================================================
# SSH Permissions Fix - Test Runner
# Runs all tests for the SSH permissions fix script
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
OVERALL_PASSED=0
OVERALL_FAILED=0
OVERALL_TOTAL=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Run a specific test suite
run_test_suite() {
    local test_file="$1"
    local test_name="${2:-$(basename "$test_file" .sh)}"

    log_info "Running test suite: $test_name"

    if [[ ! -f "$test_file" ]]; then
        log_error "Test file not found: $test_file"
        return 1
    fi

    # Source the test framework functions
    source "$SCRIPT_DIR/test-framework.sh"

    # Reset counters for this suite
    TESTS_RUN=0
    TEST_PASSED=0
    TEST_FAILED=0

    # Source and run the test file
    echo ""
    echo -e "${BLUE}Running test suite: $test_name${NC}"
    echo -e "${BLUE}$(printf '%.0s=' {1..50})${NC}"
    echo ""

    source "$test_file"

    # Update overall counters
    OVERALL_PASSED=$((OVERALL_PASSED + TEST_PASSED))
    OVERALL_FAILED=$((OVERALL_FAILED + TEST_FAILED))
    OVERALL_TOTAL=$((OVERALL_TOTAL + TESTS_RUN))

    if [[ $TEST_FAILED -eq 0 ]]; then
        log_success "Test suite $test_name: PASSED ($TEST_PASSED/$TESTS_RUN tests)"
        return 0
    else
        log_error "Test suite $test_name: FAILED ($TEST_FAILED/$TESTS_RUN tests failed)"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    log_info "SSH Permissions Fix - Complete Test Suite"
    echo "=========================================="

    local exit_code=0

    # Make sure scripts are executable
    chmod +x "$PROJECT_ROOT/utils/fix-ssh-permissions.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

    # Run unit tests
    if ! run_test_suite "$SCRIPT_DIR/unit-tests.sh" "Unit Tests"; then
        exit_code=1
    fi

    # Run integration tests
    if ! run_test_suite "$SCRIPT_DIR/integration-tests.sh" "Integration Tests"; then
        exit_code=1
    fi

    # Print summary
    echo ""
    echo "=========================================="
    echo "TEST SUMMARY"
    echo "=========================================="

    if [[ $OVERALL_FAILED -eq 0 ]]; then
        log_success "ALL TESTS PASSED! ✓"
        echo "Total tests run: $OVERALL_TOTAL"
        echo "Passed: $OVERALL_PASSED"
        echo "Failed: $OVERALL_FAILED"
    else
        log_error "SOME TESTS FAILED! ✗"
        echo "Total tests run: $OVERALL_TOTAL"
        echo "Passed: $OVERALL_PASSED"
        echo "Failed: $OVERALL_FAILED"
        exit_code=1
    fi

    return $exit_code
}

# Run quick validation tests
run_quick_validation() {
    log_info "Running quick validation tests..."

    cd "$PROJECT_ROOT"

    # Test 1: Script syntax
    if bash -n utils/fix-ssh-permissions.sh; then
        log_success "Script syntax is valid"
    else
        log_error "Script has syntax errors"
        return 1
    fi

    # Test 2: Help output
    if ./utils/fix-ssh-permissions.sh --help >/dev/null 2>&1; then
        log_success "Help command works"
    else
        log_error "Help command failed"
        return 1
    fi

    # Test 3: Dry run
    if ./utils/fix-ssh-permissions.sh --dry-run >/dev/null 2>&1; then
        log_success "Dry run works"
    else
        log_error "Dry run failed"
        return 1
    fi

    # Test 4: Test framework loads
    if source "$SCRIPT_DIR/test-framework.sh" >/dev/null 2>&1; then
        log_success "Test framework loads correctly"
    else
        log_error "Test framework failed to load"
        return 1
    fi

    log_success "Quick validation passed!"
    return 0
}

# Show usage
show_usage() {
    cat << EOF
SSH Permissions Fix - Test Runner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -a, --all          Run all tests (default)
    -u, --unit         Run only unit tests
    -i, --integration  Run only integration tests
    -q, --quick        Run quick validation tests only
    -v, --verbose      Enable verbose output

EXAMPLES:
    $0                    # Run all tests
    $0 --unit            # Run only unit tests
    $0 --quick           # Quick validation only

TEST SUITES:
    Unit Tests:         Test individual functions and components
    Integration Tests:  Test end-to-end functionality
    Quick Validation:   Basic syntax and functionality checks

EOF
}

# Parse arguments
parse_args() {
    TEST_MODE="all"
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--all)
                TEST_MODE="all"
                shift
                ;;
            -u|--unit)
                TEST_MODE="unit"
                shift
                ;;
            -i|--integration)
                TEST_MODE="integration"
                shift
                ;;
            -q|--quick)
                TEST_MODE="quick"
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"

    case "$TEST_MODE" in
        all)
            run_all_tests
            ;;
        unit)
            run_test_suite "$SCRIPT_DIR/unit-tests.sh" "Unit Tests"
            ;;
        integration)
            run_test_suite "$SCRIPT_DIR/integration-tests.sh" "Integration Tests"
            ;;
        quick)
            run_quick_validation
            ;;
        *)
            log_error "Invalid test mode: $TEST_MODE"
            exit 1
            ;;
    esac
}

# Run main if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi