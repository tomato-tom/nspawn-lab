# Makefile for nspawn container management project

# Variables
BIN_DIR := bin
LIB_DIR := lib
TESTS_DIR := tests

# Main scripts
PAW := $(BIN_DIR)/paw.sh
SETUP_NSPAWN_SCRIPT := $(LIB_DIR)/setup_nspawn.sh

# Library
LIB_MAP := misc/map_functions.sh
LIB_CONTAINER := lib/container/container.sh
LIB_BRIDGE := lib/vnet/bridge.sh
LIB_VETH := lib/vnet/veth.sh

# Test scripts
TEST_LOGGER := $(TESTS_DIR)/logger_test.sh
TEST_BRIDGE := $(TESTS_DIR)/test_bridge.sh
TEST_VETH := $(TESTS_DIR)/test_veth.sh

# Configuration files
DEFAULT_CONF := $(CONFIG_DIR)/default.conf

.PHONY: all setup test map clean help

# Default target
all: help

# Setup nspawn environment
setup:
	@echo "Setting up nspawn environment..."
	bash $(LIB_DIR)/setup_nspawn.sh

# Run all tests
test: test-logger test-bridge test-veth

# Run logger tests
test-logger:
	bash $(TEST_LOGGER)

# Run bridge tests
test-bridge:
	bash $(TEST_BRIDGE)

# Run veth tests
test-veth:
	bash $(TEST_VETH)

# Generate function maps
map: map-paw map-contaienr map-bridge map-veth

# Generating a function map for paw.sh
map-paw:
	bash $(LIB_MAP) $(PAW)

# Generating a function map for container.sh
map-container:
	bash $(LIB_MAP) $(LIB_CONTAINER)

# Generating a function map for bridge.sh
map-bridge:
	bash $(LIB_MAP) $(LIB_BRIDGE)

# Generating a function map for veth.sh
map-veth:
	bash $(LIB_MAP) $(LIB_VETH)

# Clean up log files
clean:
	rm -f $(LOGS_DIR)/*.log
	rm -f $(TESTS_DIR)/logs/*

# Help message
help:
	@echo "Available targets:"
	@echo "  make setup      - Setup nspawn environment"
	@echo "  make clean      - Clean up log files"
	@echo "  make help       - Show this help message"
	@echo "Tests:"
	@echo "  make test       - Run all tests"
	@echo "  make test-logger - Run logger tests only"
	@echo "  make test-bridge - Run bridge tests only"
	@echo "  make test-veth   - Run veth tests only"
	@echo "Maps:"
	@echo "  make map-paw"
	@echo "  make map-container"
	@echo "  make map-veth"
	@echo "  make map-bridge"
