# All commands pin the stable Xcode so local runs match CI (the machine's xcode-select may point at a beta).
export DEVELOPER_DIR ?= /Applications/Xcode.app
CONFIGURATION ?= debug

.PHONY: build test lint format app run dmg distribution-check verification-app verification-test verify clean

build:
	xcrun swift build --package-path app --scratch-path .build -c $(CONFIGURATION)

test:
	xcrun swift test --package-path app --scratch-path .build

lint:
	xcrun swift-format lint --strict --recursive app/Package.swift app/Sources app/Tests

format:
	xcrun swift-format format --in-place --recursive app/Package.swift app/Sources app/Tests

app: build
	tools/bundle-app.sh

run:
	bash tools/run-app.sh

dmg:
	CONFIGURATION=release $(MAKE) app
	bash tools/build-dmg.sh

distribution-check:
	bash tools/check-distribution.sh

verification-app:
	bash tools/build-verification-app.sh

verification-test:
	xcrun swift test --package-path app -c release --scratch-path .build/verification -Xswiftc -DWATERLINE_VERIFICATION --filter VerificationEnvironmentTests

verify: build test lint
	python3 tools/test-cask-generator.py
	python3 tools/test-run-app.py
	python3 tools/test-update-config.py
	git diff --check
	git diff --cached --check
	tools/audit.sh

clean:
	rm -rf .build build
