# CalSync1on1 Makefile

.PHONY: build run clean test install setup help check

# Default target
help:
	@echo "CalSync1on1 - macOS Calendar Sync Tool"
	@echo ""
	@echo "Available targets:"
	@echo "  build    - Build the project in release mode"
	@echo "  run      - Build and run the project"
	@echo "  debug    - Build in debug mode"
	@echo "  test     - Run tests"
	@echo "  clean    - Clean build artifacts"
	@echo "  install  - Install to /usr/local/bin"
	@echo "  setup    - Run interactive configuration setup"
	@echo "  check    - Validate build and tests"
	@echo "  help     - Show this help message"

# Build the project in release mode
build:
	swift build -c release

# Build in debug mode
debug:
	swift build

# Build and run the project
run: build
	./.build/release/calsync1on1

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Install to /usr/local/bin
install: build
	@echo "Installing calsync1on1 to /usr/local/bin..."
	@sudo cp .build/release/calsync1on1 /usr/local/bin/
	@echo "Installation complete. You can now run 'calsync1on1' from anywhere."
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run 'make setup' to configure your calendars"
	@echo "  2. Test with 'calsync1on1 --dry-run'"
	@echo "  3. If everything looks good, run 'calsync1on1'"

# Run interactive configuration setup
setup:
	@echo "Setting up CalSync1on1 configuration..."
	@./setup-config.sh

# Comprehensive validation
check: clean
	@echo "Running comprehensive validation..."
	swift package resolve
	swift build --build-tests
	swift test
	swift build -c release
	@echo "✅ All checks passed!"

# Validate project dependencies
validate:
	swift package resolve
	swift build --build-tests
