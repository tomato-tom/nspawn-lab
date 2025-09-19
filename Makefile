# Makefile for nspawn container management project

# Variables
BIN_DIR := bin
LIB_DIR := lib
CONFIG_DIR := config
LOGS_DIR := logs
TESTS_DIR := tests

# Main scripts
PAW_SCRIPT := $(BIN_DIR)/paw.sh
SETUP_NSPAWN_SCRIPT := $(LIB_DIR)/setup_nspawn.sh

# Test scripts
LOGGER_TEST := $(TESTS_DIR)/logger_test.sh
BRIDGE_TEST := $(TESTS_DIR)/test_bridge.sh

# Configuration files
DEFAULT_CONF := $(CONFIG_DIR)/default.conf

.PHONY: all setup test map clean help

# Default target
all: help

# Setup nspawn environment
setup:
	@echo "Setting up nspawn environment..."
	./$(LIB_DIR)/setup_nspawn.sh

# Run all tests
test: test-logger test-bridge

# Run logger tests
test-logger:
	bash $(LOGGER_TEST)

# Run bridge tests
test-bridge:
	bash $(BRIDGE_TEST)

# Generate script map
map:
	bash misc/map_functions.sh bin/paw.sh

# Clean up log files
clean:
	rm -f $(LOGS_DIR)/*.log
	rm -f $(TESTS_DIR)/logs/*

# Help message
help:
	@echo "Available targets:"
	@echo "  make setup      - Setup nspawn environment"
	@echo "  make test       - Run all tests"
	@echo "  make test-logger - Run logger tests only"
	@echo "  make test-bridge - Run bridge tests only"
	@echo "  make clean      - Clean up log files"
	@echo "  make tree       - Show project structure"
	@echo "  make help       - Show this help message"
