#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
working_dir=$(mktemp -d /tmp/personal-decoration-tests.XXXXXX)
trap 'rm -rf "$working_dir"' EXIT
sdk_path=${PERSONAL_TEST_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}
if [[ ! -d "$sdk_path" ]]; then sdk_path=$(xcrun --show-sdk-path); fi
# CLT has no Xcode Preview macro plugin. Exclude only the non-runtime preview
# declaration in this temporary compilation copy; production declarations are intact.
sed '/^#Preview {/,$d' boringNotch/components/Music/MusicVisualizer.swift > "$working_dir/MusicVisualizer.swift"
swiftc -swift-version 5 -sdk "$sdk_path" \
  boringNotch/components/AnimatedFace.swift \
  "$working_dir/MusicVisualizer.swift" \
  'boringNotch/components/Live activities/MarqueeTextView.swift' \
  TestsPersonal/DecorationLifecycleTests.swift -o "$working_dir/DecorationLifecycleTests"
"$working_dir/DecorationLifecycleTests"
