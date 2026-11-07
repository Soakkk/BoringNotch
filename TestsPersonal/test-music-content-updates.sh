#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe=$(mktemp -d /tmp/boring-music-updates.XXXXXX)
trap 'rm -rf "$probe"' EXIT
python3 - "$probe/ProductionUpdate.swift" <<'PY'
from pathlib import Path
import sys
source=Path('boringNotch/managers/MusicManager.swift').read_text()
start=source.index('    @MainActor\n    private func updateFromPlaybackState')
end=source.index('\n    func toggleFavoriteTrack()',start)
method=source[start:end].replace('private func updateFromPlaybackState','func updateFromPlaybackState',1)
Path(sys.argv[1]).write_text('import AppKit\nimport SwiftUI\nextension MusicUpdateProbe {\n'+method+'\n}\n')
PY
swiftc -parse-as-library -swift-version 5 -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  boringNotch/models/PlaybackState.swift TestsPersonal/MusicContentUpdateTests.swift "$probe/ProductionUpdate.swift" -o "$probe/check"
"$probe/check"
