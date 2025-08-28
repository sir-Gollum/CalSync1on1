.PHONY: help
## Show this help message
help:
	@echo "CalSync1on1 - macOS Calendar Sync Tool"
	@echo ""
	@awk 'BEGIN { \
		FS = ":.*##"; \
		printf "Usage:\n  make \033[36m<target>\033[0m\n\nTargets:\n" \
	} \
	/^[a-zA-Z_0-9-]+:.*##/ { \
		printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 \
	} \
	/^##[^@]/ { \
		getline target; \
		if (target ~ /^[a-zA-Z_0-9-]+:/) { \
			gsub(/^## */, "", $$0); \
			gsub(/:.*/, "", target); \
			printf "  \033[36m%-15s\033[0m %s\n", target, $$0 \
		} \
	} \
	/^##@/ { \
		printf "\n\033[1m%s\033[0m\n", substr($$0, 5) \
	}' $(MAKEFILE_LIST)


.PHONY: build
## Build the project in release mode
build:
	swift build -c release

.PHONY: debug
## Build in debug mode
debug:
	swift build

.PHONY: run
## Build and run the project
run: build
	./.build/release/calsync1on1

.PHONY: test
## Run tests
test:
	swift test 2>&1 | xcbeautify

.PHONY: lint
## Run linters
lint:
	swiftlint

.PHONY: format
## Run code formatter
format:
	swiftformat --verbose .

.PHONY: clean
## Clean build artifacts
clean:
	swift package clean
	rm -rf .build

.PHONY: install
## Install to /usr/local/bin
install: build
	@echo "Installing calsync1on1 to /usr/local/bin..."
	@sudo cp .build/release/calsync1on1 /usr/local/bin/
	@echo "Installation complete. You can now run 'calsync1on1' from anywhere."
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run 'make setup' to configure your calendars"
	@echo "  2. Test with 'calsync1on1 --dry-run'"
	@echo "  3. If everything looks good, run 'calsync1on1'"

.PHONY: setup
# Run interactive configuration setup
setup:
	@echo "Setting up CalSync1on1 configuration..."
	@./setup-config.sh

.PHONY: clean
# Comprehensive validation
check: clean
	@echo "Running comprehensive validation..."
	swift package resolve
	swift build --build-tests
	swift test
	swift build -c release
	@echo "✅ All checks passed!"

.PHONY: validate
# Validate project dependencies
validate:
	swift package resolve
	swift build --build-tests
