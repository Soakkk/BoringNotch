#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe="$(mktemp -d /tmp/boring-adaptive-layout.XXXXXX)"
trap 'rm -rf "$probe"' EXIT
sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
for test in AdaptiveLayoutTests AgendaClockTests; do
    swiftc -parse-as-library -sdk "$sdk" boringNotch/components/Notch/PersonalAppearance.swift "TestsPersonal/$test.swift" -o "$probe/$test"
    "$probe/$test"
done
