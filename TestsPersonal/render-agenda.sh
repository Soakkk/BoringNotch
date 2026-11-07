#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe="$(mktemp -d /tmp/personal-agenda.XXXXXX)"
trap 'rm -rf "$probe"' EXIT
python3 - "$probe/Surface.swift" <<'PY'
from pathlib import Path
import sys
source=Path('boringNotch/components/Notch/NotchHomeView.swift').read_text().split('// MARK: - Personal agenda surface',1)[1]
Path(sys.argv[1]).write_text('import SwiftUI\n'+source)
PY
swiftc -parse-as-library -swift-version 5 -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk boringNotch/components/Notch/PersonalAppearance.swift boringNotch/components/HoverButton.swift "$probe/Surface.swift" TestsPersonal/AgendaRenderTests.swift -o "$probe/check"
"$probe/check" "${1:-/tmp/boring-personal-agenda-renders}"
