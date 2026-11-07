#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
working_dir=$(mktemp -d /tmp/personal-energy-tests.XXXXXX)
trap 'rm -rf "$working_dir"' EXIT
sdk_path=${PERSONAL_TEST_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}
if [[ ! -d "$sdk_path" ]]; then sdk_path=$(xcrun --show-sdk-path); fi
sed '/^import Defaults$/d' boringNotch/managers/PersonalEnergyManager.swift > "$working_dir/PersonalEnergyManager.swift"
swiftc -swift-version 5 -sdk "$sdk_path" \
  "$working_dir/PersonalEnergyManager.swift" TestsPersonal/PersonalEnergyTests.swift \
  -o "$working_dir/PersonalEnergyTests"
"$working_dir/PersonalEnergyTests"
