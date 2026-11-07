#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
working_dir=$(mktemp -d /tmp/personal-segmented-tests.XXXXXX)
trap 'rm -rf "$working_dir"' EXIT
sdk_path=${PERSONAL_TEST_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}
if [[ ! -d "$sdk_path" ]]; then sdk_path=$(xcrun --show-sdk-path); fi
# Exercise the actual inline percentage expression without pulling the whole
# app and its device managers into the CLT-only native verification executable.
python3 - "$working_dir/InlinePercentage.swift" <<'PY'
from pathlib import Path
import sys
lines = Path('boringNotch/components/Live activities/InlineHUD.swift').read_text().splitlines()
matches = [line.strip() for line in lines if 'Text("' in line and '%"' in line and 'value' in line]
assert len(matches) == 1
expression = matches[0][len('Text('):-1]
Path(sys.argv[1]).write_text('import SwiftUI\nfunc renderInlineHUDPercentage(_ value: CGFloat) -> String { ' + expression + ' }\n')
PY
swiftc -parse-as-library -swift-version 5 -sdk "$sdk_path" \
  'boringNotch/components/Live activities/SegmentedHUD.swift' \
  "$working_dir/InlinePercentage.swift" \
  TestsPersonal/SegmentedHUDTests.swift -o "$working_dir/SegmentedHUDTests"
"$working_dir/SegmentedHUDTests" "${1:-/tmp/boring-segmented-hud-renders}"
