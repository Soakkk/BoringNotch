#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe="$(mktemp -d /tmp/boring-calendar-order.XXXXXX)"
trap 'rm -rf "$probe"' EXIT
sed '/^import Defaults$/d' boringNotch/managers/CalendarManager.swift > "$probe/CalendarManager.swift"
swiftc -parse-as-library -swift-version 5 -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk "$probe/CalendarManager.swift" TestsPersonal/CalendarOrderingTests.swift -o "$probe/check"
"$probe/check"
