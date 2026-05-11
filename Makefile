.PHONY: project build test clean

DEST ?= 'platform=iOS Simulator,name=iPhone 15'
DD := build

project:
	xcodegen generate

build: project
	xcodebuild -scheme GBIFNearby -destination $(DEST) -derivedDataPath $(DD) -quiet build

test: project
	xcodebuild -scheme GBIFNearby -destination $(DEST) -derivedDataPath $(DD) -quiet test

clean:
	rm -rf GBIFNearby.xcodeproj build

app-path:
	@find $(DD)/Build/Products -name 'GBIFNearby.app' -print -quit
