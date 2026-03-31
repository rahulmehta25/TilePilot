.PHONY: build install clean test run dmg lint help

BINARY_NAME = TilePilot
BUILD_DIR = .build/release
INSTALL_DIR = /usr/local/bin

# Default target
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build release binary
	swift build -c release

run: build ## Build and run
	$(BUILD_DIR)/$(BINARY_NAME)

install: build ## Install to /usr/local/bin
	@mkdir -p $(INSTALL_DIR)
	cp $(BUILD_DIR)/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "Installed $(BINARY_NAME) to $(INSTALL_DIR)"

uninstall: ## Remove from /usr/local/bin
	rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "Removed $(BINARY_NAME) from $(INSTALL_DIR)"

clean: ## Clean build artifacts
	swift package clean
	rm -rf .build

test: ## Run tests
	swift test

lint: ## Run SwiftLint (if installed)
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

format: ## Run swift-format (if installed)
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format format --recursive Sources Tests --in-place; \
	else \
		echo "swift-format not installed. Install with: brew install swift-format"; \
	fi

dmg: build ## Create a DMG for distribution (placeholder)
	@echo "Creating DMG..."
	@mkdir -p dist
	@cp $(BUILD_DIR)/$(BINARY_NAME) dist/
	@hdiutil create -volname "$(BINARY_NAME)" \
		-srcfolder dist/ \
		-ov -format UDZO \
		dist/$(BINARY_NAME).dmg 2>/dev/null || \
		echo "DMG creation requires a proper .app bundle. Use Xcode Archive for production builds."
	@rm -rf dist/$(BINARY_NAME)
	@echo "DMG created at dist/$(BINARY_NAME).dmg"

resolve: ## Resolve SPM dependencies
	swift package resolve

update: ## Update SPM dependencies
	swift package update
