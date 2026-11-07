# Music layout A implementation plan

> Execute inline with executing-plans and one fresh whole-change review before publication.

**Goal:** Ship the user-approved A preview: larger left artwork, metadata and moderate transport controls together on its right, full-width progress below.
**Architecture:** Reuse the existing native SwiftUI player and playback actions. A shared value-driven layout also feeds native visual fixtures. Keep the existing energy policy and updater identity.
**Tech stack:** SwiftUI/AppKit, macOS 15+, universal GitHub build, signed Sparkle feed and archive.
**Spec:** User-approved preview `artifacts/2026-11-07-boring-music-layouts/opcion-1.png` in the parent workspace; existing adaptive spec `../specs/2026-11-07-personal-adaptive.md` applies except version and music composition.

## Global constraints
- Opened content remains 640×190 pt and host 640×210 pt; same calendar, themes, auto-hide, energy policy and separate app identity.
- Empty-day music width stays 340 pt; artwork becomes 84 pt. Existing smaller widths remain adaptive. Progress stays full width.
- Title uses at most two static lines, artist one; lyrics-enabled state uses one title line to retain height.
- Preserve customizable slot order and all playback actions. If controls (including expanded volume) cannot fit beside the artwork, keep them in a full-width row above progress, within the same 128 pt content height.
- Version 3.1.1 / build 301001. Reuse authorized local-signing exception, sandbox, keys, update feed and install path.

## Review focus
Long title/artist; narrow paused player; five customized slots and expanded volume; optional lyrics; legacy camera player and default HoverButton callers.

## Task 1: Player layout and visual verification
Files: `PersonalAppearance.swift`, `NotchHomeView.swift`, `HoverButton.swift`, native render fixtures and release metadata.
- [ ] Implement generic lateral layout, compact opt-in buttons and static song metadata; preserve legacy camera path and playback callbacks.
- [ ] Render the production layout at 340/264/216 pt with all three themes, long titles, paused/lyrics/custom controls; inspect a bounded comparison sheet.
- [ ] Run existing adaptive, energy, decoration, calendar and publication checks. No mirrored unit tests for reversible layout/style edits; native render and interaction checks verify the change.
- [ ] Commit and obtain one independent code review; fix any material findings.

## Task 2: Signed release and local update
- [ ] Build universal app/helper and signed five-file release allowlist from the exact reviewed commit.
- [ ] Verify package identity/signatures/checksums, install over the one Applications path with recoverable backup, restart and inspect real layout/playback/agenda.
- [ ] Merge and publish installer/ZIP first, exact signed feed last; verify anonymous downloads and native updater.
- [ ] Clean verification app copies recoverably, leave installed app running, record evidence.

## Execution ledger
- Existing dedicated checkout was clean; reuse it on feature branch `codex/personal-music-layout-a`.
- Implementation, publication, local update/restart and the existing app-only signing exception are explicitly authorized; no additional permission gate applies.
- UI-only changes use native rendering rather than implementation-mirroring tests; existing behavioral regressions remain required.
