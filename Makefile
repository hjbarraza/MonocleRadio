# Makefile — Build, bundle, sign, and package Monocle Radio
# Usage:
#   make app       build release .app bundle
#   make dmg       create DMG installer (uses hdiutil, or create-dmg if installed)
#   make run       build and run debug
#   make clean     remove build artifacts

APP_NAME      := Monocle Radio
BUNDLE_ID     := com.monocle.radio
VERSION       := 1.0.0
BUILD_DIR     := build
APP_BUNDLE    := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR  := $(APP_BUNDLE)/Contents
DMG_PATH      := $(BUILD_DIR)/MonocleRadio-$(VERSION).dmg

# Ad-hoc signing by default. Set to your Developer ID for distribution:
#   make app SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
SIGN_IDENTITY ?= -

.PHONY: app dmg run clean

app:
	@echo "[████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 10% Building release binary..."
	@swift build -c release --quiet
	@echo "[████████████████░░░░░░░░░░░░░░░░░░░░░░░░░] 40% Creating .app bundle..."
	@mkdir -p "$(CONTENTS_DIR)/MacOS" "$(CONTENTS_DIR)/Resources"
	@cp .build/release/MonocleRadio "$(CONTENTS_DIR)/MacOS/MonocleRadio"
	@/usr/libexec/PlistBuddy -c "Clear dict" "$(CONTENTS_DIR)/Info.plist" 2>/dev/null; true
	@/usr/libexec/PlistBuddy \
		-c "Add :CFBundleExecutable string MonocleRadio" \
		-c "Add :CFBundleIdentifier string $(BUNDLE_ID)" \
		-c "Add :CFBundleName string $(APP_NAME)" \
		-c "Add :CFBundleVersion string $(VERSION)" \
		-c "Add :CFBundleShortVersionString string $(VERSION)" \
		-c "Add :CFBundlePackageType string APPL" \
		-c "Add :LSUIElement bool true" \
		-c "Add :LSMinimumSystemVersion string 14.0" \
		-c "Add :NSAppTransportSecurity dict" \
		-c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" \
		"$(CONTENTS_DIR)/Info.plist"
	@echo "[██████████████████████████░░░░░░░░░░░░░░░] 65% Signing..."
	@codesign --force --sign "$(SIGN_IDENTITY)" "$(APP_BUNDLE)"
	@echo "[████████████████████████████████████████░] 100% Done"
	@echo ""
	@echo "✓ $(APP_BUNDLE)"
	@du -sh "$(APP_BUNDLE)" | awk '{print "  Size: " $$1}'

dmg: app
	@echo "[████████████████████████████████████░░░░░] 90% Creating DMG..."
	@rm -rf "$(BUILD_DIR)/dmg-staging" "$(DMG_PATH)"
	@mkdir -p "$(BUILD_DIR)/dmg-staging"
	@cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg-staging/"
	@ln -sf /Applications "$(BUILD_DIR)/dmg-staging/Applications"
	@cp README.md "$(BUILD_DIR)/dmg-staging/READ ME FIRST.md"
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(BUILD_DIR)/dmg-staging" \
		-ov -format UDZO "$(DMG_PATH)"
	@rm -rf "$(BUILD_DIR)/dmg-staging"
	@echo "[████████████████████████████████████████░] 100% Done"
	@echo ""
	@echo "✓ $(DMG_PATH)"
	@du -sh "$(DMG_PATH)" | awk '{print "  Size: " $$1}'

run:
	@swift run

clean:
	@rm -rf $(BUILD_DIR) .build
	@echo "✓ Cleaned"
