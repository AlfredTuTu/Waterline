# All commands pin the stable Xcode so local runs match CI (the machine's xcode-select may point at a beta).
export DEVELOPER_DIR ?= /Applications/Xcode.app
CONFIGURATION ?= debug

.PHONY: build test lint format app run verify clean

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

run: app
	pkill -x WaterlineApp || true
	open -n build/Waterline.app

verify: build test lint
	git diff --check
	git diff --cached --check
	Scripts/audit.sh

clean:
	rm -rf .build build
