#!/bin/bash
# test_veth.sh
# Test suite for veth.sh functions

# Test configuration
LOG_FILE="/tmp/veth_test.log"
ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/.. && pwd)"
readonly TEST_DIR="$ROOTDIR/tests"
readonly SCRIPT_DIR="$ROOTDIR/lib/vnet"
readonly TEST_VETH_A="test-veth-a"
readonly TEST_VETH_B="test-veth-b"
readonly TEST_BRIDGE="test-br0"
readonly TEST_NETNS="test-ns"
readonly TEST_IP="192.168.201.10/24"

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
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

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
        # Show actual error for debugging
        echo "Command failed: $cmd" >&3
        eval "$cmd" >&3 2>&3 || true
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

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="${3:-contains check}"
    
    ((TESTS_RUN++))
    log test "Testing: $description"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        log info "✓ PASS: $description"
        ((TESTS_PASSED++))
        return 0
    else
        log error "✗ FAIL: $description ('$haystack' should contain '$needle')"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log error "This test suite must be run as root (network operations require privileges)"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("ip")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log error "Required dependency '$dep' not found"
            exit 1
        fi
    done
    
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
    
    # Source the veth script
    if ! source "$SCRIPT_DIR/veth.sh"; then
        log error "Failed to source veth.sh"
        exit 1
    fi
    
    # Clean up any existing test resources
    cleanup_test_resources || true
}

# Cleanup test resources
cleanup_test_resources() {
    log info "Cleaning up test resources..."
    
    # Remove test veth interfaces
    local test_veths=("$TEST_VETH_A" "$TEST_VETH_B" "long-veth-name-test" "short")
    for veth in "${test_veths[@]}"; do
        if veth_exists "$veth" 2>/dev/null; then
            veth_delete "$veth" 2>/dev/null || true
        fi
    done
    
    # Remove test bridge
    if ip link show "$TEST_BRIDGE" >/dev/null 2>&1; then
        ip link set "$TEST_BRIDGE" down 2>/dev/null || true
        ip link delete "$TEST_BRIDGE" 2>/dev/null || true
    fi
    
    # Remove test namespace
    if ip netns list 2>/dev/null | grep -q "^$TEST_NETNS"; then
        ip netns delete "$TEST_NETNS" 2>/dev/null || true
    fi
}

# Test veth validation
test_veth_validation() {
    log test "=== Testing Veth Validation ==="
    
    # Valid veth names
    assert_success "veth_validate_name 'veth0'" "Valid veth name 'veth0'"
    assert_success "veth_validate_name 'test-veth'" "Valid veth name with dash"
    assert_success "veth_validate_name 'veth_test'" "Valid veth name with underscore"
    assert_success "veth_validate_name 'veth123'" "Valid veth name with numbers"
    assert_success "veth_validate_name 'v.eth'" "Valid veth name with dot"
    
    # Invalid veth names
    assert_failure "veth_validate_name ''" "Empty veth name should fail"
    assert_failure "veth_validate_name 'very-long-veth-name'" "Too long veth name should fail"
    assert_failure "veth_validate_name 'veth with spaces'" "Veth name with spaces should fail"
    assert_failure "veth_validate_name 'veth@special'" "Veth name with invalid special chars should fail"
}

# Test veth existence checking
test_veth_exists() {
    log test "=== Testing Veth Existence Checking ==="
    
    # Test non-existent veth
    assert_failure "veth_exists '$TEST_VETH_A'" "Non-existent veth should not exist"
    
    # Create veth pair and test existence
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create test veth pair"
    assert_success "veth_exists '$TEST_VETH_A'" "First veth should exist after creation"
    assert_success "veth_exists '$TEST_VETH_B'" "Second veth should exist after creation"
    
    # Clean up
    assert_success "veth_delete '$TEST_VETH_A'" "Delete test veth pair"
    assert_failure "veth_exists '$TEST_VETH_A'" "First veth should not exist after deletion"
    assert_failure "veth_exists '$TEST_VETH_B'" "Second veth should not exist after deletion"
}

# Test veth pair creation and deletion
test_veth_lifecycle() {
    log test "=== Testing Veth Pair Lifecycle ==="
    
    # Test initial non-existence
    assert_failure "veth_exists '$TEST_VETH_A'" "Veth A should not exist initially"
    assert_failure "veth_exists '$TEST_VETH_B'" "Veth B should not exist initially"
    
    # Test creation
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair"
    assert_success "veth_exists '$TEST_VETH_A'" "Veth A should exist after creation"
    assert_success "veth_exists '$TEST_VETH_B'" "Veth B should exist after creation"
    
    # Test duplicate creation (should fail)
    assert_failure "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Duplicate creation should fail"
    
    # Test deletion by one interface
    assert_success "veth_delete '$TEST_VETH_A'" "Delete veth pair by first interface"
    assert_failure "veth_exists '$TEST_VETH_A'" "Veth A should not exist after deletion"
    assert_failure "veth_exists '$TEST_VETH_B'" "Veth B should not exist after deletion"
    
    # Test deletion of non-existent interface
    assert_failure "veth_delete '$TEST_VETH_A'" "Delete non-existent veth should fail"
}

# Test veth pair deletion by both names
test_veth_delete_pair() {
    log test "=== Testing Veth Pair Deletion ==="
    
    # Create test pair
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair for pair deletion test"
    
    # Test pair deletion
    assert_success "veth_delete_pair '$TEST_VETH_A' '$TEST_VETH_B'" "Delete veth pair by both names"
    assert_failure "veth_exists '$TEST_VETH_A'" "Veth A should not exist after pair deletion"
    assert_failure "veth_exists '$TEST_VETH_B'" "Veth B should not exist after pair deletion"
    
    # Test pair deletion when only one exists (create new pair, delete one, then try pair deletion)
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create new veth pair"
    assert_success "veth_delete '$TEST_VETH_A'" "Delete one veth"
    assert_failure "veth_delete_pair '$TEST_VETH_A' '$TEST_VETH_B'" "Pair deletion should fail when neither exists"
}

# Test veth up/down operations
test_veth_state() {
    log test "=== Testing Veth State Operations ==="
    
    # Create veth pair
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair for state testing"
    
    # Test bringing up interface
    assert_success "veth_up '$TEST_VETH_A'" "Bring veth A up"

    # Test status to check if only one side is up
    local status_a status_b
    status_a=$(veth_status "$TEST_VETH_A")
    status_b=$(veth_status "$TEST_VETH_B")
    assert_equals "LOWERLAYERDOWN" "$status_a" "Veth A status should be LOWERLAYERDOWN"
    assert_equals "DOWN" "$status_b" "Veth B status should be DOWN"

    # Test bringing up interface
    assert_success "veth_up '$TEST_VETH_B'" "Bring veth B up"
    
    # Test status checking if both sides are up
    status_a=$(veth_status "$TEST_VETH_A")
    status_b=$(veth_status "$TEST_VETH_B")
    assert_equals "UP" "$status_a" "Veth A status should be UP"
    assert_equals "UP" "$status_b" "Veth B status should be UP"
    
    # Test bringing down interfaces
    assert_success "veth_down '$TEST_VETH_A'" "Bring veth A down"
    assert_success "veth_down '$TEST_VETH_B'" "Bring veth B down"
    
    status_a=$(veth_status "$TEST_VETH_A")
    status_b=$(veth_status "$TEST_VETH_B")
    assert_equals "DOWN" "$status_a" "Veth A status should be DOWN"
    assert_equals "DOWN" "$status_b" "Veth B status should be DOWN"
    
    # Clean up
    assert_success "veth_delete '$TEST_VETH_A'" "Clean up state test veth pair"
}

# Test veth attachment to bridge
test_veth_bridge_attachment() {
    log test "=== Testing Veth Bridge Attachment ==="
    
    # Create test bridge
    assert_success "ip link add '$TEST_BRIDGE' type bridge" "Create test bridge"
    assert_success "ip link set '$TEST_BRIDGE' up" "Bring test bridge up"
    
    # Create veth pair
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair for bridge test"
    
    # Test attachment to bridge
    assert_success "veth_attach '$TEST_VETH_A' '$TEST_BRIDGE'" "Attach veth to bridge"
    
    # Verify attachment
    local bridge_output
    bridge_output=$(ip link show "$TEST_VETH_A" 2>/dev/null | grep "master" || echo "no-master")
    assert_contains "$bridge_output" "$TEST_BRIDGE" "Veth should be attached to bridge"
    
    # Test detachment
    assert_success "veth_detach '$TEST_VETH_A'" "Detach veth from bridge"
    
    # Clean up
    assert_success "veth_delete '$TEST_VETH_A'" "Clean up bridge test veth pair"
    assert_success "ip link delete '$TEST_BRIDGE'" "Clean up test bridge"
}

# Test veth attachment to network namespace
test_veth_netns_attachment() {
    log test "=== Testing Veth Network Namespace Attachment ==="
    
    # Create test namespace
    assert_success "ip netns add '$TEST_NETNS'" "Create test namespace"
    
    # Create veth pair
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair for netns test"
    
    # Test attachment to namespace
    assert_success "veth_attach '$TEST_VETH_B' '$TEST_NETNS'" "Attach veth to namespace"
    
    # Verify attachment (veth should not be visible in default namespace)
    assert_failure "veth_exists '$TEST_VETH_B'" "Veth should not exist in default namespace"
    
    # Verify it exists in the namespace
    assert_success "ip netns exec '$TEST_NETNS' ip link show '$TEST_VETH_B' >/dev/null" "Veth should exist in namespace"
    
    # Clean up (deleting from default namespace should clean up the pair)
    assert_success "veth_delete '$TEST_VETH_A'" "Clean up netns test veth pair"
    assert_success "ip netns delete '$TEST_NETNS'" "Clean up test namespace"
}

# Test IP address configuration
test_veth_ip_config() {
    log test "=== Testing Veth IP Configuration ==="
    
    # Create veth pair
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair for IP test"
    assert_success "veth_up '$TEST_VETH_A'" "Bring veth A up"
    
    # Test IP configuration
    assert_success "veth_set_ip '$TEST_VETH_A' '$TEST_IP'" "Set IP on veth"
    
    # Verify IP configuration
    local ip_output
    ip_output=$(ip addr show "$TEST_VETH_A" 2>/dev/null | grep "${TEST_IP%/*}" || echo "no-ip")
    assert_contains "$ip_output" "${TEST_IP%/*}" "Veth should have configured IP"
    
    # Test IP removal
    assert_success "veth_del_ip '$TEST_VETH_A' '$TEST_IP'" "Remove IP from veth"
    
    # Clean up
    assert_success "veth_delete '$TEST_VETH_A'" "Clean up IP test veth pair"
}

# Test IP configuration in namespace
test_veth_netns_ip_config() {
    log test "=== Testing Veth IP Configuration in Namespace ==="
    
    # Create test namespace
    assert_success "ip netns add '$TEST_NETNS'" "Create test namespace for IP test"
    
    # Create veth pair and move one to namespace
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair for netns IP test"
    assert_success "veth_attach '$TEST_VETH_B' '$TEST_NETNS'" "Move veth to namespace"
    
    # Bring up interfaces
    assert_success "veth_up '$TEST_VETH_A'" "Bring veth A up"
    assert_success "ip netns exec '$TEST_NETNS' ip link set '$TEST_VETH_B' up" "Bring veth B up in namespace"
    
    # Test IP configuration in namespace
    assert_success "veth_set_ip '$TEST_VETH_B' '$TEST_IP' '$TEST_NETNS'" "Set IP on veth in namespace"
    
    # Verify IP configuration in namespace
    assert_success "ip netns exec '$TEST_NETNS' ip addr show '$TEST_VETH_B' | grep -q '${TEST_IP%/*}'" "Veth should have IP in namespace"
    
    # Test IP removal in namespace
    assert_success "veth_del_ip '$TEST_VETH_B' '$TEST_IP' '$TEST_NETNS'" "Remove IP from veth in namespace"
    
    # Clean up
    assert_success "veth_delete '$TEST_VETH_A'" "Clean up netns IP test veth pair"
    assert_success "ip netns delete '$TEST_NETNS'" "Clean up test namespace"
}

# Test error handling
test_error_handling() {
    log test "=== Testing Error Handling ==="
    
    # Test operations on non-existent veth
    assert_failure "veth_delete 'non-existent-veth'" "Delete non-existent veth should fail"
    assert_failure "veth_up 'non-existent-veth'" "Bring up non-existent veth should fail"
    assert_failure "veth_down 'non-existent-veth'" "Bring down non-existent veth should fail"
    assert_failure "veth_attach 'non-existent-veth' 'some-target'" "Attach non-existent veth should fail"
    
    # Test missing parameters
    assert_failure "veth_create ''" "Create veth with empty name should fail"
    #assert_failure "veth_create '$TEST_VETH_A' ''" "Create veth with empty peer name should fail"
    #assert_failure "veth_attach ''" "Attach with empty veth name should fail"
    #assert_failure "veth_attach '$TEST_VETH_A' ''" "Attach with empty target should fail"
    
    # Test invalid targets for attachment
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth for invalid target test"
    assert_failure "veth_attach '$TEST_VETH_A' 'invalid-target'" "Attach to invalid target should fail"
    assert_success "veth_delete '$TEST_VETH_A'" "Clean up invalid target test"
    
    # Test name length validation in create function
    assert_failure "veth_create 'very-very-long-veth-name-that-exceeds-limit' 'short'" "Too long first name should fail"
    assert_failure "veth_create 'short' 'very-very-long-veth-name-that-exceeds-limit'" "Too long second name should fail"
}

# Test veth listing and information
test_veth_info() {
    log test "=== Testing Veth Information Functions ==="
    
    # Test list when no veths exist
    assert_failure "veth_list >/dev/null" "List should fail when no veths exist"
    
    # Create some veth pairs
    assert_success "veth_create '$TEST_VETH_A' '$TEST_VETH_B'" "Create veth pair for info testing"
    assert_success "veth_create 'info-test-1' 'info-test-2'" "Create second veth pair for info testing"
    
    # Test list
    assert_success "veth_list >/dev/null" "List should work when veths exist"
    
    # Test list pairs
    assert_success "veth_list_pairs >/dev/null" "List pairs should work"
    
    # Test info
    assert_success "veth_info '$TEST_VETH_A' >/dev/null" "Info should work for existing veth"
    assert_failure "veth_info 'non-existent-veth' >/dev/null" "Info should fail for non-existent veth"
    
    # Test status
    local status
    status=$(veth_status "$TEST_VETH_A")
    # Status should be either UP or DOWN (depending on default state)
    assert_success "[[ '$status' == 'UP' || '$status' == 'DOWN' ]]" "Status should return valid state"
    
    # Test status for non-existent veth
    status=$(veth_status "non-existent-veth" 2>/dev/null || echo "NOT_EXISTS")
    assert_equals "NOT_EXISTS" "$status" "Status should return NOT_EXISTS for non-existent veth"
    
    # Clean up
    assert_success "veth_delete '$TEST_VETH_A'" "Clean up info test veth pair 1"
    assert_success "veth_delete 'info-test-1'" "Clean up info test veth pair 2"
}

# Print test summary
print_summary() {
    echo >&3
    echo "==================== TEST SUMMARY ====================" >&3
    echo "Tests run: $TESTS_RUN" >&3
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}" >&3
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}" >&3
    echo "Log file: $LOG_FILE" >&3
    echo "=======================================================" >&3
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}" >&3
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}" >&3
        return 1
    fi
}

# Cleanup on exit
cleanup_on_exit() {
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        cleanup_test_resources >/dev/null 2>&1 || true
    fi
    
    # Restore stdout/stderr
    exec 1>&3 2>&4
}

# Main test runner
main() {
    trap cleanup_on_exit EXIT
    init
    
    echo "Starting veth.sh test suite..."
    echo "Log file: $LOG_FILE"
    echo
    
    # Pre-test checks
    check_root
    check_dependencies
    setup_test_env
    
    # Run test suites
    test_veth_validation || true
    test_veth_exists || true
    test_veth_lifecycle || true
    test_veth_delete_pair || true
    test_veth_state || true
    test_veth_bridge_attachment || true
    test_veth_netns_attachment || true
    test_veth_ip_config || true
    test_veth_netns_ip_config || true
    test_error_handling || true
    test_veth_info || true
    
    # Print results
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
