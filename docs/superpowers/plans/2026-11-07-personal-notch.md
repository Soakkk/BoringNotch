# BoringNotch Personal Implementation Plan

> Execute the already approved design autonomously. Use executing-plans for integration and dispatching-parallel-agents for disjoint UI/performance/release work; one fresh whole-change review before publication.

**Goal:** Ship the approved compact agenda/music redesign with lower idle rendering, own automatic updates and one working installation on this Mac.
**Architecture:** Existing SwiftUI/AppKit/EventKit/media coordinators; transient agenda navigation remains UI state. Reuse upstream media and storage logic. Sparkle uses a dedicated signed feed and per-project key.
**Tech Stack:** Swift 5, SwiftUI/AppKit, EventKit, Sparkle, GitHub macOS Actions.
**Spec:** ../specs/2026-11-07-personal-notch.md

## Global constraints
640×190 opened panel, 640×210 shadow host. Separate from FocusNotch. Preserve GPL attribution and existing settings/shelf via backup. No fabricated production event data. Personal app 3.0.0/build300000. No upstream update URLs in personal runtime.

## Tasks
- [x] UI: root owns NotchHomeView.swift and existing calendar view, music timeline flags, copy and fixture render harness. Implement three readable agenda rows and same-size detail/day navigation; preserve no-calendar/provider/camera states. Validate actual native render at exact bounds and long/empty/denied fixtures; native real app build in CI.
- [x] Performance: independent worker owns AnimatedFace.swift, MusicVisualizer.swift, MarqueeTextView.swift and lifecycle-focused tests only. Cancel repeating resources and pause decorative work; no UI redesign overlap. Regression verifies repeated mount/unmount does not accumulate work.
- [x] Release: independent worker owns xcodeproj, Info.plist, helper identity configuration, own release scripts/workflow and release metadata only. Produce universal ad-hoc personal build with sandbox/runtime and signed appcast, assert own IDs/feed/key, artifact allowlist and version. Root owns key generation/secrets, publication, local migration/install. No source private keys/tokens/credentials.
- [x] Integration: baseline CI build, targeted regression tests, rendered UI review and fresh whole-branch review. Fix important findings in one bounded pass. Publish public installer/feed, anonymous hash/signature verification.
- [x] Install: archive original app and preserve protected settings/shelf container, quit through UI, install one personal app, manually restore principal preferences, verify calendar/media/geometry/updates and measure idle CPU. Deliver three alternative visual previews. Automatic protected-data migration was unavailable; see evidence below.

## Review focus
Calendar dates/empty/denied/loading/long and all-day events; rapid navigation late results must not overwrite selected day. Paused/playing/seek changes keep the clock correct with no periodic paused redraw. Repeated open/close cancels decorative work. Update signatures/URLs and bundle/helper IDs remain consistent. Migration must preserve shelf/security-scoped bookmarks and not touch FocusNotch.

## Verification evidence

- Native UI fixture renders: summary, detail, empty, denied and loading at exactly640×190. Long titles wrap in summary; all-day and reminder rows remain visible.
- Decoration lifecycle regression:24 native checks pass against actual view/timer implementations, with real pixel-motion checks and RED/mutation evidence. SDK26.5 is used locally because fullXcode is absent.
- CalendarManager real-source test reproduces a late reminder fetch overwriting a newly selected day (RED), then passes after routing every awaited refresh through request ordering (GREEN). Reminder-only read access is preserved; write-only event authorization is not treated as read access.
- Whole-branch independent review completed. Both important calendar findings above were fixed. No further important release/identity/signature finding.
- Universal Xcode app+helper builds passed, including final compiled source581d7d2 in run42369277708. Packaging exposed Bash3 argument handling and THIRD_PARTY_LICENSES file-copy assumptions; both fixed. Compiled inputs are unchanged through release sourced5588fb. Final packaging/signing/identity verification completed locally with that CI binary.
- Actual hardened-runtime ad-hoc loader probe fails for Sparkle andMediaRemoteAdapter with differentTeamIDs. A separate diagnostic probe with app-only library-validation exception loads both successfully. Source/installer documentation records the flag. The user explicitly approved the app-only exception; the installed personal app retains sandbox and hardened runtime. No system-wide security setting changed.
- New Ed25519 signing seed is in protected local storage outside the repository, imported to its ownKeychain account, and supplied to repositoryActions via BORINGNOTCH_SPARKLE_PRIVATE_KEY. Only the public key is in source.
- Original app archived at ~/Library/Application Support/BoringNotch Backups/pre-personal-3.0.0-20261107-123731/original-app.zip. macOSprivacy blocks shell reads of the original protectedcontainer; that container is preserved untouched. Automatic settings/shelf migration is not verified and must not be claimed.
- Three conceptual alternatives generated: Esencial, Agenda andGrafito; image at workspace/artifacts/boringnotch-personal/variantes.png. Approved black/mint design remains the implemented default.


## Installed release verification — 2026-11-07

- PR1 merged with merge commit26ab99a; release personal-v3.0.0 targets sourced5588fb. Published DMG, ZIP, manifest, checksums and signed feed. The exact signed feed is active on main/updater/personal-appcast.xml.
- Anonymous downloads of all five public assets completed. All four asset hashes match SHA256SUMS; public raw feed bytes match the release feed. Both feed and update archive pass Ed25519 verification against the pinned public key.
- /Applications/BoringNotch Personal.app is running version3.0.0/build300000, with own identity. Original app and staging app bundles are recoverably in Trash; original archived backup and protected data container remain available. FocusNotch was not modified.
- Existing Google calendar sources and real events are visible through macOS Calendar/EventKit. Summary, next-day navigation and full title detail were inspected within the same640×190 content bounds. Spotify play and pause were verified; Spotify was left paused.
- Main preferences restored manually: login enabled, built-in display, hover and haptics enabled, menu icon/shelf/expanded drag detection disabled. Optional camera/reminders/Accessibility setup skipped. This is not a claim of automatic shelf/bookmark migration.
- Following onboarding the panel required one quit/relaunch to become interactive; no source-level cause/fix was proven. Normal operation and a subsequent launch were verified after restart.
- Idle sample over25.005s after opening the panel with Spotify paused:0.00% of one CPU core by process CPU-time delta, RSS128.6MiB. Short snapshot only; not a controlled whole-day battery comparison or a claim of zero CPU during playback.
- Installed Sparkle check displayed: “¡Está actualizado! BoringNotch Personal3.0.0 es la versión más nueva disponible.” Automatic checks and automatic downloads both ON.
- Three visual alternatives delivered in workspace/artifacts/boringnotch-personal/variantes.png. These are concepts; the installed default is the approved compact black/mint music+agenda design.
