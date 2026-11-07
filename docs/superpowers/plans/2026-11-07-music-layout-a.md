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
- [x] Implement generic lateral layout, compact opt-in buttons and static song metadata; preserve legacy camera path and playback callbacks.
- [x] Render the production layout at 340/264/216 pt with all three themes, long titles, paused/lyrics/custom controls; inspect a bounded comparison sheet.
- [x] Run existing adaptive, energy, decoration, calendar and publication checks. No mirrored unit tests for reversible layout/style edits; native render and interaction checks verify the change.
- [x] Commit and obtain one independent code review; fix any material findings.

## Task 2: Signed release and local update
- [x] Build universal app/helper and signed five-file release allowlist from the exact reviewed commit.
- [x] Verify package identity/signatures/checksums, install over the one Applications path with recoverable backup, restart and inspect real layout/playback/agenda.
- [x] Merge and publish installer/ZIP first, exact signed feed last; verify anonymous downloads and native updater.
- [x] Clean verification app copies recoverably, leave installed app running, record evidence.

## Execution ledger
- Existing dedicated checkout was clean; reuse it on feature branch `codex/personal-music-layout-a`.
- Implementation, publication, local update/restart and the existing app-only signing exception are explicitly authorized; no additional permission gate applies.
- UI-only changes use native rendering rather than implementation-mirroring tests; existing behavioral regressions remain required.
- User added resource/battery optimization during execution. Audit found repeated content effects for a same-album track with unchanged artwork, and duplicate lyrics requests on late artwork. Added native regressions executing the production update method with intercepted external effects; reproduced both failures before fixing metadata bookkeeping and limiting lyric fetches to metadata changes. Timing and playback-control propagation stay unchanged.
- Review of initial layout commit393f691 found no actionable regressions. All existing behavioral suites passed; 18 native music and 18 full-panel renders inspected. The first CI run was cancelled to include the newly requested resource fix in the final build.

- Final source: `8483c53ff565dc977810fab604359a69c03190a2`. Independent review found no actionable regressions in layout or the subsequent resource fix; reviewer independently reran all eight music regressions.
- Final targeted suites pass: 14 adaptive/date checks, 24 energy checks, 25 decoration checks, 8 music-update checks, calendar request ordering and publication guard. Native rendering covered 18 music fixtures and 18 complete 640×190 pt panels. No new polling or rendering timers were introduced.
- CI run `42375752113` completed universal build, helper, signing and five-file artifact packaging successfully. PR3 merged in `1256fab33bd689ab769442367122a04c9d1552d9`.
- Installed and restarted 3.1.1/build301001 at the existing Applications path, preserving preferences/container. Strict code signature, sandbox, approved app-only library-validation exception and embedded source identity verified. Previous installed bundle and ZIP backup remain recoverable; verification app moved to Trash.
- macOS showed existing calendar/reminder permissions enabled while the newly installed process reported denied. Refreshed the same grants through System Settings and used its restart action; actual calendar events and empty-day state then worked. No TCC database edits or global security changes. Inspected wide A layout, narrow paused layout with three actual agenda rows, Grafito preference and active intelligent saving.
- Public release `personal-v3.1.1` contains the exact five verified assets. Signed feed activated last in `f39ca78534dad2103a65b4a6007d8ec74cf58c17`; anonymous downloads match local checksums and pinned-key feed/ZIP Ed25519 verification passes. Native updater reports3.1.1 as latest; automatic checks and downloads are both on.
- Resource sample after restart: 25.02 seconds, panel visible at start, Spotify paused, energy saving active. App/helper each used0.000% mean CPU at the process-time counter resolution; RSS159.4MiB +8.9MiB. The earlier closed-panel3.1.0 sample also had negligible idle CPU. These are short observations in different visible states, not a battery-life or RAM-reduction claim.
