#!/usr/bin/env sh
# Xcode Cloud entry point. Runs after the repo is cloned and before xcodebuild.
# GBIFNearby.xcodeproj is .gitignored — XcodeGen generates it from project.yml —
# so we install xcodegen and produce the project here.
set -eu
brew install xcodegen
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
