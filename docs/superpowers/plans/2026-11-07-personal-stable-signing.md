# Stable personal signing implementation plan

> **For agentic workers:** Use superpowers:executing-plans in the existing dedicated checkout, with one independent whole-branch review before release.

**Goal:** Preserve BoringNotch's existing privacy grants across ordinary updates by signing every version with the same personal certificate, and prove the result through an actual consecutive-version update on the user's Mac.

**Architecture:** Replace ad-hoc release signing with a persistent, certificate-pinned personal identity. Import its protected PKCS#12 into an isolated temporary keychain for each packaging run, sign nested code inside out and fail closed on missing or mismatched credentials. Keep Sparkle's separate Ed25519 authentication and existing app/helper identifiers unchanged.

**Tech Stack:** Python release scripts, macOS codesign/security, OpenSSL certificate generation, GitHub Actions repository secrets, existing SwiftUI app and Sparkle.

**Spec:** User-approved proposal in this chat: own stable signing certificate without an Apple subscription, protected private key in the GitHub publishing system, one initial permission migration, then verification with two consecutive versions. Apple TN3127 explains privacy grant identity; TN2206 documents personal certificate signing.

## Global constraints

- Existing checkout, branch `codex/personal-stable-signing`; do not touch FocusNotch.
- Keep `com.soakkk.BoringNotch`, helper `com.soakkk.BoringNotch.BoringNotchXPCHelper`, `/Applications/BoringNotch Personal.app`, macOS 15 minimum and universal arm64/x86_64.
- Preserve the pinned Sparkle key, signed feed/archive checks, sandbox, hardened runtime and previously authorized app-only library-validation exception.
- Do not weaken Gatekeeper, SIP, TCC or any global trust setting. A new trust requirement beyond the authorized personal identity must be made concrete and handled explicitly.
- Private key and passwords never enter source, artifacts or logs. Store a protected local backup outside the repository; transmit only to the explicitly approved repository secrets.
- No UI, resource polling, timers or functionality changes. Preserve existing theme, selections and energy preferences.
- Use 3.1.3/build 301003 as the migration candidate and 3.1.4/build 301004 as the consecutive final release. Only the final release needs public promotion. All product work remains in this branch until reviewed.

## Review focus

- Missing credentials and mismatched certificates must stop signing rather than fall back to ad-hoc.
- Different app contents signed with the pinned certificate must satisfy each other's designated requirements; another certificate or ad-hoc signature must fail.
- App, XPC helper and nested framework/tools retain valid signatures and their existing entitlements.
- Keychain import failures and signing failures must clean up temporary private files without logging secret values and restore the normal keychain search list after its temporary registration during signing.
- The installed first candidate must retain its granted Accessibility/calendar/reminder access after a normal Sparkle update to the second candidate, without a second authorization.

### Task 1: Certificate identity and native signing regression

**Files:** Create `Scripts/personal_codesign.py`, `TestsPersonal/test-stable-signing.py`, `Release/codesign-certificate.pem`; modify `Scripts/personal-release.py` and release metadata.

**Interfaces:** `sign_app(app, library_exception)` signs using environment `BORINGNOTCH_CODESIGN_P12_BASE64` and `BORINGNOTCH_CODESIGN_PASSWORD`, validates the identity against the committed public certificate and returns certificate fingerprint metadata. A temporary keychain exists only inside its context.

- [x] Write a native regression that builds two different fixture apps/helpers, invokes the current release signer and checks mutual designated-requirement compatibility; observe failure with ad-hoc signing.
- [x] Add cases rejecting missing credentials, an unrelated private identity and ad-hoc or wrong-certificate replacements; preserve sandbox/runtime and helper requirements.
- [x] Implement the certificate-pinned signer, temporary keychain lifecycle and safe failure reporting. Run native tests to green.
- [x] Create the persistent app-specific code-signing certificate once, protect its local PKCS#12/password backup, commit only its public certificate and pin, and store the two private values as repository secrets through standard encrypted GitHub handling.
- [x] Commit the tested signing implementation.

### Task 2: Release enforcement and CI

**Files:** Modify `.github/workflows/personal-build.yml`, `Scripts/check-personal-publication.py`, `TestsPersonal/test-publication-guard.py`, `Release/personal.json`, `Release/README.md`, Xcode version fields and README version.

**Interfaces:** Manifest `signing=personal-certificate`, `codesign_certificate_sha256` equals the committed metadata pin, `notarized=false`; same five-file artifact allowlist. CI injects both certificate secrets only into the explicitly requested signing step.

- [x] Observe publication regressions for ad-hoc, unknown/missing signing and a mismatched fingerprint, then enforce pinned certificate signing before publication.
- [x] Connect CI secret import and native signing tests, retaining source SHA checks, signed artifact allowlist and publication ordering.
- [x] Prepare 3.1.3 migration commit, then 3.1.4 final commit; run release/signature and native regression checks.
- [x] Obtain one independent whole-branch review. Address any important finding with a failing regression first.
- [x] Build and verify both reviewed candidates: source, certificate, mutual requirements, app/helper architectures, entitlements, archive/feed signatures and hashes.

### Task 3: Permission migration, real update and publication

**Files:** Release evidence in this plan, signed feed, protected recovery copy outside the repository.

**Interfaces:** First candidate at the existing installation path; second candidate delivered through the existing Sparkle feed with a strictly increasing build and identical certificate identity.

- [x] Back up 3.1.2, install 3.1.3 and renew only existing grants through native settings/user handoff. Verify HUD, calendar/reminders and preferences before proceeding.
- [x] Merge reviewed source; publish the final five verified assets, verify public downloads, then activate the exact signed feed bytes last.
- [x] Use the first candidate's normal updater to install 3.1.4. Confirm the same path, expected version, identical signing identity and retained permissions without reauthorizing.
- [x] Verify normal panel, automatic checks/downloads and no regression in settled resource use. Record exact evidence and any limits; finish with a clean synchronized repository.

## Completed execution evidence

- Six native signing tests and ten publication-policy tests passed locally and in GitHub. Existing segmented-HUD and release-signature checks passed. Independent review found no blocking defect.
- Hosted signing exposed a documented `codesign` requirement: the temporary identity keychain must be registered in the search list even when explicitly selected. The regression was observed failing and then passing; the exact previous list is restored on success and native signing failure. No trust settings changed.
- Migration source: `0d190eb6147940c712a1d2a566a39a85bf4bf68a`, run `42398919379`, version 3.1.3/build 301003.
- Final source: `4fa58a90decc68650f41dde04f31b099571cb78c`, run `42398928503`, version 3.1.4/build 301004.
- Both downloaded artifact archives match GitHub digests. All five release assets, hashes, Sparkle feed/archive signatures, actual app/helper certificate pins, mutual designated requirements, universal architectures and existing entitlements verified. Final publication guard passed.
- 3.1.2 backed up; 3.1.3 installed and launched at the existing Applications path. Accessibility renewed through native settings and custom indicators restored. The user accepted the initial calendar/reminder renewal; both lists and existing selections were verified before updating again.
- PR #5 merged as `48f322d92f95eff7a65fa60b6f4c5a463abe4410`. The final release was staged as a draft while awaiting user interaction, then published as `personal-v3.1.4`. All five anonymous public downloads matched the verified local artifacts before the signed feed was activated in `188ed2987354804702393b472d64094a50bba0d6`. The live feed matched its exact signed bytes and passed Ed25519 verification.
- **Real update acceptance passed:** the running 3.1.3 app discovered 3.1.4 through its normal Sparkle updater, downloaded it, installed it and relaunched itself. No manual app replacement, permission reset, settings regrant or user permission acceptance occurred during this second update. Version 3.1.4/build 301004 and the source SHA were verified at `/Applications/BoringNotch Personal.app`; the installed app and helper retained the pinned certificate.
- After the update, native settings showed recognized Accessibility and custom indicators enabled, both calendar/reminder lists with the existing selections, theme Esencial, Ahorro inteligente on, and automatic checks/downloads on. The normal music/calendar panel rendered and settings were closed. This proves the tested consecutive update on this Mac; future identity changes or OS policy changes are outside that result.
- Resource observation with music paused: baseline 3.1.2 over25.06seconds measured0.0% main/helperCPU at ps resolution, RSS84.0/7.0MiB. The25.07seconds after3.1.4 UI checks measured0.479% mainCPU,0.0% helperCPU, RSS151.5/8.9MiB. This is a short observation near startup, not a battery benchmark or a claim of equal steady-state memory. No application timers or background-work code changed.
- Minor deferred test coverage: a direct native-import-failure cleanup assertion. Native signing-failure cleanup is now automated and passing; wrong-password failure and missing/mismatched identities are covered.
