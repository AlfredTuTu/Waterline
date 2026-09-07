# All commands pin the stable Xcode so local runs match CI (the machine's xcode-select may point at a beta).
export DEVELOPER_DIR ?= /Applications/Xcode.app
CONFIGURATION ?= debug

.PHONY: build test lint format app run dmg distribution-check verification-app verification-test verify clean

build:
	xcrun swift build -c $(CONFIGURATION)

test:
	xcrun swift test

lint:
	xcrun swift-format lint --strict --recursive Package.swift Sources Tests

format:
	xcrun swift-format format --in-place --recursive Package.swift Sources Tests

app: build
	Scripts/bundle-app.sh

run:
	bash Scripts/run-app.sh

dmg:
	CONFIGURATION=release $(MAKE) app
	bash Scripts/build-dmg.sh

distribution-check:
	bash Scripts/check-distribution.sh

verification-app:
	bash Scripts/build-verification-app.sh

verification-test:
	xcrun swift test -c release --scratch-path .build/verification -Xswiftc -DWATERLINE_VERIFICATION --filter VerificationEnvironmentTests

verify: build test lint
	python3 Scripts/test-cask-generator.py
	git diff --check
	git diff --cached --check
	Scripts/audit.sh

clean:
	rm -rf .build build
