#!/bin/bash
# test_bridge.sh
# Test suite for bridge.sh functions

set -euo pipefail

# Test configuration
LOG_FILE="/tmp/bridge_test.log"
ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/.. && pwd)"
readonly TEST_DIR="$ROOTDIR/tests"
readonly SCRIPT_DIR="$ROOTDIR/lib/vnet"
readonly TEST_BRIDGE="test-br0"
readonly TEST_CONTAINER="test-01"
readonly TEST_IP="192.168.200.1/24"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup flag
CLEANUP_ON_EXIT=true

# Initialize logging
init() {
    if source "$ROOTDIR/lib/common.sh"; then
        load_logger $0 $LOG_FILE
        check_root || return 1
    else
        echo "Failed to source common.sh" >&2
        return 1
    fi
}

# Test assertion functions
assert_success() {
    local cmd="$1"
    local description="${2:-$cmd}"
    
    ((TESTS_RUN++))
    log test "Testing: $description"
    
    if eval "$cmd" >/dev/null 2>&1; then
        log info "✓ PASS: $description"
        ((TESTS_PASSED++))
        return 0
    else
        log error "✗ FAIL: $description"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_failure() {
    local cmd="$1"
    local description="${2:-$cmd}"
    
    ((TESTS_RUN++))
    log test "Testing: $description"
    
    if ! eval "$cmd" >/dev/null 2>&1; then
        log info "✓ PASS: $description (expected failure)"
        ((TESTS_PASSED++))
        return 0
    else
        log error "✗ FAIL: $description (should have failed)"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="${3:-value comparison}"
    
    ((TESTS_RUN++))
    log test "Testing: $description"
    
    if [[ "$expected" == "$actual" ]]; then
        log info "✓ PASS: $description (expected: '$expected', got: '$actual')"
        ((TESTS_PASSED++))
        return 0
    else
        log error "✗ FAIL: $description (expected: '$expected', got: '$actual')"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Wait for interface to be up (with timeout)
wait_for_interface_up() {
    local interface="$1"
    local timeout="${2:-5}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        local state
        state=$(ip link show "$interface" 2>/dev/null | grep -oP 'state \K\w+' || echo "NOT_FOUND")
        if [[ "$state" == "UP" ]]; then
            return 0
        fi
        sleep 0.5
        ((count++))
    done
    return 1
}

# Check dependencies
check_dependencies() {
    local deps=("ip" "bridge")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log error "Required dependency '$dep' not found"
            exit 1
        fi
    done
    
    # Check if bridge.sh exists
    if [[ ! -f "$SCRIPT_DIR/bridge.sh" ]]; then
        log error "bridge.sh not found at $SCRIPT_DIR/bridge.sh"
        exit 1
    fi
    
    # Check if veth.sh exists
    if [[ ! -f "$SCRIPT_DIR/veth.sh" ]]; then
        log error "veth.sh not found at $SCRIPT_DIR/veth.sh"
        exit 1
    fi
}

# Setup test environment
setup_test_env() {
    log info "Setting up test environment..."
    
    # Remove test log file
    rm -f "$LOG_FILE"
    
    # Source the bridge script (which sources veth.sh)
    if ! source "$SCRIPT_DIR/bridge.sh"; then
        log error "Failed to source bridge.sh"
        exit 1
    fi
    
    # Clean up any existing test resources
    cleanup_test_resources || true
}

# Cleanup test resources
cleanup_test_resources() {
    log info "Cleaning up test resources..."
    
    # Remove test bridge
    if bridge_exists "$TEST_BRIDGE" 2>/dev/null; then
        bridge_delete "$TEST_BRIDGE" 2>/dev/null || true
    fi
    
    # Remove test namespace
    if ip netns exec "ns-$TEST_CONTAINER" 2>/dev/null; then
        ip netns delete "ns-$TEST_CONTAINER" 2>/dev/null || true
    fi
    
    # Remove test veth interfaces
    ip link show "ve-$TEST_CONTAINER" 2>/dev/null && {
        ip link delete "$iface" 2>/dev/null || true
    }
}

# Test bridge validation
test_bridge_validation() {
    log test "=== Testing Bridge Validation ==="
    
    # Valid bridge names
    assert_success "bridge_validate_name 'br0'" "Valid bridge name 'br0'"
    assert_success "bridge_validate_name 'test-bridge'" "Valid bridge name with dash"
    assert_success "bridge_validate_name 'br_test'" "Valid bridge name with underscore"
    assert_success "bridge_validate_name 'bridge123'" "Valid bridge name with numbers"
    
    # Invalid bridge names
    assert_failure "bridge_validate_name ''" "Empty bridge name should fail"
    assert_failure "bridge_validate_name 'very-long-bridge-name-that-exceeds-limit'" "Too long bridge name should fail"
    assert_failure "bridge_validate_name 'br with spaces'" "Bridge name with spaces should fail"
    assert_failure "bridge_validate_name 'br@special'" "Bridge name with special chars should fail"
}

# Test bridge creation and deletion
test_bridge_lifecycle() {
    log test "=== Testing Bridge Lifecycle ==="
    
    # Test bridge doesn't exist initially
    assert_failure "bridge_exists '$TEST_BRIDGE'" "Test bridge should not exist initially"
    
    # Test bridge creation
    assert_success "bridge_create '$TEST_BRIDGE'" "Create test bridge"
    assert_success "bridge_exists '$TEST_BRIDGE'" "Test bridge should exist after creation"
    
    # Test duplicate creation (should not fail)
    assert_success "bridge_create '$TEST_BRIDGE'" "Creating existing bridge should not fail"
    
    # Test bridge deletion
    assert_success "bridge_delete '$TEST_BRIDGE'" "Delete test bridge"
    assert_failure "bridge_exists '$TEST_BRIDGE'" "Test bridge should not exist after deletion"
    
    # Test deleting non-existent bridge
    assert_failure "bridge_delete '$TEST_BRIDGE'" "Deleting non-existent bridge should fail"
}

# Test bridge with IP configuration
test_bridge_ip_config() {
    log test "=== Testing Bridge IP Configuration ==="
    
    # Create bridge with IP
    assert_success "bridge_create '$TEST_BRIDGE' '$TEST_IP'" "Create bridge with IP address"
    assert_success "bridge_exists '$TEST_BRIDGE'" "Bridge with IP should exist"
    
    # Wait for interface to be ready
    sleep 0.3
    
    # Check if IP is configured (basic check)
    local has_ip
    if ip addr show "$TEST_BRIDGE" 2>/dev/null | grep -q "${TEST_IP%/*}"; then
        has_ip="true"
    else
        has_ip="false"
    fi
    assert_equals "true" "$has_ip" "Bridge should have configured IP address"
    
    # Clean up
    assert_success "bridge_delete '$TEST_BRIDGE'" "Clean up bridge with IP"
}

# Test bridge up/down operations
test_bridge_state() {
    log test "=== Testing Bridge State Operations ==="
    
    # Create bridge for testing
    assert_success "bridge_create '$TEST_BRIDGE'" "Create bridge for state testing"
    
    # attach container
    bridge_attach $TEST_BRIDGE $TEST_CONTAINER
    #sleep 0.3

    # Test bridge up
    assert_success "bridge_up '$TEST_BRIDGE'" "Bring bridge up"
    sleep 0.3
    local status_up
    status_up=$(bridge_status "$TEST_BRIDGE")
    assert_equals "UP" "$status_up" "Bridge status should be UP"
    
    # Test bridge down
    assert_success "bridge_down '$TEST_BRIDGE'" "Bring bridge down"
    local status_down
    status_down=$(bridge_status "$TEST_BRIDGE")
    assert_equals "DOWN" "$status_down" "Bridge status should be DOWN"
    
    # Test cleanup
    assert_success "bridge_cleanup_container '$TEST_CONTAINER' '$TEST_BRIDGE'" "Cleanup container resources"

    # Clean up
    assert_success "bridge_delete '$TEST_BRIDGE'" "Clean up bridge after state testing"
}

# Test bridge attach/detach operations
test_bridge_attach_detach() {
    log test "=== Testing Bridge Attach/Detach Operations ==="
    
    # Create bridge for testing
    assert_success "bridge_create '$TEST_BRIDGE'" "Create bridge for attach testing"
    
    # Wait for bridge to be ready
    sleep 0.3
    
    # Test attach container
    assert_success "bridge_attach '$TEST_BRIDGE' '$TEST_CONTAINER'" "Attach container to bridge"
    
    # Verify namespace was created
    assert_success "ip netns exec 'ns-$TEST_CONTAINER' true" "Network namespace should be created"
    
    # Test detach container
    assert_success "bridge_detach '$TEST_BRIDGE' '$TEST_CONTAINER'" "Detach container from bridge"
    
    # Test cleanup
    assert_success "bridge_cleanup_container '$TEST_CONTAINER' '$TEST_BRIDGE'" "Cleanup container resources"
    
    # Clean up bridge
    assert_success "bridge_delete '$TEST_BRIDGE'" "Clean up test bridge"
}

# Test error handling
test_error_handling() {
    log test "=== Testing Error Handling ==="
    
    # Test operations on non-existent bridge
    assert_failure "bridge_delete 'non-existent-bridge'" "Delete non-existent bridge should fail"
    assert_failure "bridge_show 'non-existent-bridge'" "Show non-existent bridge should fail"
    assert_failure "bridge_detach 'non-existent-bridge' '$TEST_CONTAINER'" "Detach from non-existent bridge should fail"
    
    # Test missing parameters - need to test this differently because of default values
    # Use a function that doesn't have defaults
    assert_failure "bridge_validate_name ''" "Validate empty bridge name should fail"
}

# Test bridge listing and information
test_bridge_info() {
    log test "=== Testing Bridge Information Functions ==="
    
    # Create test bridge
    assert_success "bridge_create '$TEST_BRIDGE' '$TEST_IP'" "Create bridge for info testing"
    
    # Wait for interface to be ready
    sleep 0.3
    
    # Test bridge list (should not fail)
    assert_success "bridge_list >/dev/null" "Bridge list should work"
    
    # Test bridge show
    assert_success "bridge_show '$TEST_BRIDGE' >/dev/null" "Bridge show should work"
    
    # Clean up
    assert_success "bridge_delete '$TEST_BRIDGE'" "Clean up bridge after info testing"
}

# Test default values
test_default_values() {
    log test "=== Testing Default Values ==="
    
    # Test functions with default bridge name
    assert_success "bridge_create" "Create bridge with default name"
    sleep 0.3
    assert_success "bridge_exists" "Check existence with default name"
    assert_success "bridge_up" "Bring up bridge with default name"
    assert_success "bridge_down" "Bring down bridge with default name"
}

# Performance and stress testing
test_performance() {
    log test "=== Testing Performance ==="
    
    # Simple performance test
    assert_success "bridge_create '$TEST_BRIDGE'" "Create bridge for performance test"
    assert_success "bridge_up '$TEST_BRIDGE' && bridge_down '$TEST_BRIDGE'" "Rapid up/down operations"
    assert_success "bridge_delete '$TEST_BRIDGE'" "Clean up performance test bridge"
}

# Print test summary
print_summary() {
    echo ""
    echo "==================== TEST SUMMARY ===================="
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo "Log file: $LOG_FILE"
    echo "======================================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Cleanup on exit
cleanup_on_exit() {
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        cleanup_test_resources >/dev/null 2>&1 || true
    fi
}

# Main test runner
main() {
    trap cleanup_on_exit EXIT
    init
    echo "Starting bridge.sh test suite..."
    echo "Log file: $LOG_FILE"
    echo
    
    # Pre-test checks
    check_root
    check_dependencies
    setup_test_env
    
    # Run test suites
    test_bridge_validation || true
    test_bridge_lifecycle || true
    test_bridge_ip_config || true
    test_bridge_state || true
    
    test_bridge_attach_detach || true
    test_error_handling || true
    test_bridge_info || true
    test_default_values || true
    test_performance || true
    
    #Print results
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
