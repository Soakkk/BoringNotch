# Personal Adaptive 3.1 Implementation Plan

> Use executing-plans for integration and dispatching-parallel-agents for disjoint energy and localization domains; one fresh whole-change review before release. User has selected these improvements; continue autonomously within the approved scope.

**Goal:** Deliver a compact adaptive music/agenda panel with three coherent skins, adaptive energy saving and Spanish UI.
**Architecture:** Existing SwiftUI/AppKit/EventKit providers and signed Sparkle pipeline; pure layout/theme values and event-driven energy state.
**Tech Stack:** Swift5, native macOS15+, GitHub universal build.
**Spec:** ../specs/2026-11-07-personal-adaptive.md

## Global constraints
Keep640×190pt opened and640×210pt host. Hide normally. No pinning/new event actions/shelf changes/FocusNotch integration. Version3.1.0 build301000. Same bundle IDs/key/feed; app-only approved local signing exception. Use current dedicated clone and feature branch.

## Review focus
- Empty versus loading/denied calendar must choose correct layout.
- Pause/no track must retain visible working transport controls.
- Battery/sleep/Reduce Motion must stop decoration and wake must resume correct state without accumulating timers.
- All three skins fit long Spanish/event/song titles at exact bounds.
- Day rollover and event completion must not leave stale agenda or overwrite another selected day.

## Tasks
- [x] Task1 Energy: independent worker owns PersonalEnergyManager.swift, ContentView.swift and MediaControllers plus targeted tests. Export PersonalEnergyManager.shared ObservableObject with allowsDecorativeAnimation, screenIsAwake, progressInterval and conservesEnergy, and Defaults.adaptiveEnergySaving defaulttrue. Root consumes interface in music/agenda UI and settings. Verify meaningful RED/GREEN native policy/lifecycle and provider scenarios; use existing battery events/OS notifications and avoid duplicate polling. No edits to NotchHomeView, SettingsView, Constants, localization catalog or release files.
- [x] Task2 Spanish: independent worker owns Localizable.xcstrings and narrow user-copy fixes in models/BatteryStatusViewModel.swift and components/Onboarding. Fill missing Spanish catalog entries, validate placeholder preservation. Report dynamic settings labels for root. Do not touch energy/UI layout/settings/release files.
- [x] Task3 UI: root owns PersonalAppearance.swift, NotchHomeView.swift, BoringHeader.swift, SettingsView.swift plus adaptive/render tests. Pure PersonalPanelLayout selects music width/art sizing from playing, empty, loading, denied and detail. Test decision cases then implement; render actual value-driven surfaces at exact bounds for all skins and playing/paused/empty/detail. Retain three agenda rows and player controls, source colors, hide behavior. Set energy-saving and skin controls in Appearance; root can add redraw gating to home using Task1 interface.
- [ ] Task4 Integrate/release: root reviews diffs and runs targeted native suites and one whole-change review. Bump metadata/plist/project consistently, universal CI build and sign. Inspect real installed behavior and UI, public signature/hash and update checks. Preserve one app installation and existing data; record bounded CPU sample. Publish through own repo/feed and leave app running.

## Execution ledger
- Ruling: selected chat scope is approved; no extra design approval gate. Reuse dedicated clean checkout and existing publication/install authorization.
- Ruling: pure UI polish/localization uses render/copy validation, not mirrored unit tests; meaningful tests cover energy and adaptive state logic.

- Ruling: provider audit confirmed Spotify/Apple Music event-driven and NowPlaying streamed; keep transport unchanged. Optional YouTube fallback lifecycle issues are deferred to a separate provider revision; this release applies the shared visual energy policy to every source.
- Energy policy native checks:24 passed, including independent sleep/display/session/lock flags and battery/LowPower/thermal/ReduceMotion; no policy timer. Existing decorative lifecycle checks:24 passed.
- Adaptive layout tests:10 passed after demonstrated baseline failure; day rollover:4 passed after baseline failure. Existing CalendarManager ordering and publication guard pass.
- Native fixtures:18 combinations of three themes and summary/paused/detail/empty/denied/loading at640×190. Actual agenda component rendered; music fixture is representative and installed production player still requires visual verification.
- Fresh whole-change review found two multiline marquee call sites missing the energy gate. Both corrected to match the title; child MarqueeText native pause/static regression verifies the same stop path. No other actionable review findings.
- Spanish catalog reviewed and dynamic settings/onboarding/media/battery/camera labels localized, preserving non-Spanish entries and formatted placeholders.

- CI42372361536 rejected writing the read-only SwiftUI accessibilityReduceMotion environment value. Replaced that injection with a backward-compatible animationEnabled face parameter. Native pixel-motion regression demonstrated failure when disabled was ignored; verified static face beyond the blink interval after gating the cancellable task.
