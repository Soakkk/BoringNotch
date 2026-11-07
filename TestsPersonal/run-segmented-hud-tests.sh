#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
working_dir=$(mktemp -d /tmp/personal-segmented-tests.XXXXXX)
trap 'rm -rf "$working_dir"' EXIT
sdk_path=${PERSONAL_TEST_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}
if [[ ! -d "$sdk_path" ]]; then sdk_path=$(xcrun --show-sdk-path); fi
swiftc -parse-as-library -swift-version 5 -sdk "$sdk_path" \
  'boringNotch/components/Live activities/SegmentedHUD.swift' \
  TestsPersonal/SegmentedHUDTests.swift -o "$working_dir/SegmentedHUDTests"
"$working_dir/SegmentedHUDTests" "${1:-/tmp/boring-segmented-hud-renders}"
