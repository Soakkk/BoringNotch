#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe=$(mktemp -d /tmp/boring-music-render.XXXXXX)
trap 'rm -rf "$probe"' EXIT
swiftc -parse-as-library -swift-version 5 -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  boringNotch/components/Notch/PersonalAppearance.swift \
  boringNotch/components/HoverButton.swift TestsPersonal/MusicLayoutRender.swift -o "$probe/render"
"$probe/render" "${1:-/tmp/boring-music-layout-renders}"
