# Segmented HUD implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement these tasks in this checkout, followed by one independent code review.

**Goal:** Install the approved Segmentada design for BoringNotch's brightness and volume indicators and publish Personal 3.1.2.

**Architecture:** A shared native SwiftUI segmented meter renders twenty rounded segments, using bounded, interruptible value animations. Closed, inline and open HUDs reuse it while retaining the existing media-key handling, brightness/volume managers, notch dimensions and auto-hide lifecycle.

**Tech Stack:** SwiftUI/AppKit, existing adaptive energy policy, GitHub Actions universal builds, existing signed Sparkle feed.

**Spec:** User-approved Segmentada animated preview in this chat, 7 November 2026: icon and short label above twenty rounded segments, small percentage at the trailing edge, brief sequential illumination, no idle animation. Compact surfaces adapt the same design to their existing space.

## Global constraints

- BoringNotch remains separate from FocusNotch. Keep the 640 × 190 pt open panel and existing installation path.
- Volume, screen brightness and keyboard backlight remain continuous controls; the twenty segments are presentation only.
- Reuse existing permission handling, signatures, sandbox, update key and app-only signing exception. No global security changes.
- Respect Reduce Motion, adaptive battery savings and asleep/locked state. No new polling, timers or dependencies.
- Preserve existing accent, gradient, percentage and glow preferences; suppress decorative glow in energy saving.
- Spanish interface. Existing microphone status remains intact.

## Review focus

- Values zero/full scale, out-of-range and non-finite input must not create invalid geometry.
- Dragging must preserve fractions and deliver the change callback once, including keyboard backlight.
- The narrow inline and open surfaces must fit without changing the panel's dimensions.
- Rapid repeat input retargets existing animations; hidden, battery and Reduce Motion states have no decorative work.
- After an ad-hoc update, existing privacy grants may refer to the previous binary; verify live permissions and renew only the existing grants through macOS UI if necessary.

### Task 1: Shared segmented HUD and native verification

**Files:** Create `boringNotch/components/Live activities/SegmentedHUD.swift`, `TestsPersonal/SegmentedHUDTests.swift`, `TestsPersonal/run-segmented-hud-tests.sh`. Modify the three existing HUD views, `ContentView.swift`, and Xcode source registration.

**Interfaces:** `SegmentedLevel` supplies sanitized unit values, twenty-segment display counts, and continuous drag input. `SegmentedLevelBar` consumes value binding, appearance options, animation permission and one change callback. `SegmentedHUD` composes label, symbol, percentage and meter for standard/compact presentation.

- [x] Write and run native regression checks for input endpoints, fractional drag, invalid dimensions/values and single callback delivery; observe failure before implementation.
- [x] Implement the shared view; connect all HUD surfaces and the existing energy policy. Preserve microphone rendering and input semantics.
- [x] Render native standard/compact/inline fixtures at zero, normal and full values; inspect them together.
- [x] Run `bash TestsPersonal/run-segmented-hud-tests.sh`, existing energy and decoration tests. Expected: every assertion passes, no clipping in native fixtures.
- [x] Commit the feature and obtain an independent review of the branch.

### Task 2: Signed release, local installation and publication

**Files:** `Release/personal.json`, Xcode version/build, `README.md`, release description, `updater/personal-appcast.xml`.

**Interfaces:** Release version `3.1.2`, build `301002`, existing five-file signed release allowlist and pinned Sparkle key.

- [x] Run appropriate existing regressions, release-signature and publication-guard checks; expected all pass.
- [x] Build the reviewed commit through `personal-build.yml` with publication disabled. Verify archive/feed signatures, hashes, identifiers and universal app/helper.
- [x] Back up the current installation, gracefully quit, replace the same app and relaunch. Verify indicator settings, restored permissions, normal panel behavior and resource use.
- [x] Merge reviewed source, publish five verified assets, then activate the exact signed feed bytes last. Verify anonymous downloads and feed.
- [x] Record installed version, checks and any remaining user-only hardware-key verification.

## Release and local verification evidence

- Reviewed source: `993a316d6965671b22224b46d2f38441e6a02cd1`; PR [#4](https://github.com/Soakkk/BoringNotch/pull/4) merged.
- Universal build and signed packaging: [run 42395876685](https://github.com/Soakkk/BoringNotch/actions/runs/42395876685), successful.
- 27 native HUD checks and seven native render fixtures; energy 24, decoration 25, adaptive layout 14, music 8. The independent review's unsafe inline percentage conversion was fixed with a failing regression first.
- [Personal 3.1.2](https://github.com/Soakkk/BoringNotch/releases/tag/personal-v3.1.2) has the five expected assets. Anonymous downloads match local SHA-256 hashes. The active feed matches the signed release bytes and verifies with the pinned Ed25519 key.
- Local version 3.1.2/build 301002 replaces the existing Applications copy; its source marker, universal app/helper, deep code signature, sandbox and existing app-only library exception were verified. The previous copy is recoverable and preferences are preserved.
- Local verification completed: the user confirmed that both physical volume and brightness keys display segmented indicators. The running app's closed volume HUD was also visually inspected at 56%; normal music/calendar layout, auto-hide and calendar/reminder selections remain available.
- The stale ad-hoc Accessibility grant was renewed by removing its old entry and adding the current Applications copy after user authentication. Calendar and reminder switches alone retained the old code requirement; targeted `tccutil reset Calendar com.soakkk.BoringNotch` and `tccutil reset Reminders com.soakkk.BoringNotch`, an app restart and the user's acceptance of the native prompts restored the existing grants. No global resets or expanded permissions were used.
- Ahorro inteligente was found disabled and enabled in the native UI to honor the user's low-consumption preference. Automatic update checks and downloads are enabled. Sparkle's native check confirms that Personal 3.1.2 is the newest version.
- Settled sample with music paused and settings closed: 25.07 seconds, app/helper CPU both 0.0% at the resolution of `ps` accumulated CPU time; resident memory 122.3/7.1 MiB. This is an idle smoke check, not a battery-life benchmark. All planned checks are complete.
