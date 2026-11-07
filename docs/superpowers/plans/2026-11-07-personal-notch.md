# BoringNotch Personal Implementation Plan

> Execute the already approved design autonomously. Use executing-plans for integration and dispatching-parallel-agents for disjoint UI/performance/release work; one fresh whole-change review before publication.

**Goal:** Ship the approved compact agenda/music redesign with lower idle rendering, own automatic updates and one working installation on this Mac.
**Architecture:** Existing SwiftUI/AppKit/EventKit/media coordinators; transient agenda navigation remains UI state. Reuse upstream media and storage logic. Sparkle uses a dedicated signed feed and per-project key.
**Tech Stack:** Swift 5, SwiftUI/AppKit, EventKit, Sparkle, GitHub macOS Actions.
**Spec:** ../specs/2026-11-07-personal-notch.md

## Global constraints
640×190 opened panel, 640×210 shadow host. Separate from FocusNotch. Preserve GPL attribution and existing settings/shelf via backup. No fabricated production event data. Personal app 3.0.0/build300000. No upstream update URLs in personal runtime.

## Tasks
- [ ] UI: root owns NotchHomeView.swift and existing calendar view, music timeline flags, copy and fixture render harness. Implement three readable agenda rows and same-size detail/day navigation; preserve no-calendar/provider/camera states. Validate actual native render at exact bounds and long/empty/denied fixtures; native real app build in CI.
- [ ] Performance: independent worker owns AnimatedFace.swift, MusicVisualizer.swift, MarqueeTextView.swift and lifecycle-focused tests only. Cancel repeating resources and pause decorative work; no UI redesign overlap. Regression verifies repeated mount/unmount does not accumulate work.
- [ ] Release: independent worker owns xcodeproj, Info.plist, helper identity configuration, own release scripts/workflow and release metadata only. Produce universal ad-hoc personal build with sandbox/runtime and signed appcast, assert own IDs/feed/key, artifact allowlist and version. Root owns key generation/secrets, publication, local migration/install. No source private keys/tokens/credentials.
- [ ] Integration: baseline CI build, targeted regression tests, rendered UI review and fresh whole-branch review. Fix important findings in one bounded pass. Publish public installer/feed, anonymous hash/signature verification.
- [ ] Install: backup original app/settings/shelf, quit through UI, replace one app, migrate settings, open and verify calendar/media/geometry/updates plus paused-open/closed CPU. Protected OS permission dialogs may require user takeover. Record evidence and deliver three alternative visual previews.

## Review focus
Calendar dates/empty/denied/loading/long and all-day events; rapid navigation late results must not overwrite selected day. Paused/playing/seek changes keep the clock correct with no periodic paused redraw. Repeated open/close cancels decorative work. Update signatures/URLs and bundle/helper IDs remain consistent. Migration must preserve shelf/security-scoped bookmarks and not touch FocusNotch.
