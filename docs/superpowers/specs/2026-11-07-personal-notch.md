# BoringNotch Personal — approved design

User approved the two-state black/mint preview and requested implementation, own GitHub repository, automatic updates and installation on this Mac. Other variants are previews only; implement the approved default now. FocusNotch stays completely separate, with no imports, IPC or shared timer/history.

Preserve openNotchSize 640×190 points and windowSize 640×210 including shadow. Main view shows compact music on the left and a readable three-row agenda on the right. Selecting agenda replaces music with full-width agenda detail in the same footprint; return restores music. Calendar dates navigate without resizing; selected-calendar permissions, loading, empty and denied states remain usable. Actual events and playback drive production UI, never preview fixtures.

Quiet rendering: pause progress and lyric timelines when music is paused; remove repeated decorative work when invisible, honor Reduce Motion, cancel face/visualizer timers on disappearance. Keep existing media providers, shelf, camera and settings functional. Preserve settings and shelf data via explicit backup/migration on install.

Base: main b7611bb, avoiding wholesale adoption of experimental dev. Personal repository Soakkk/BoringNotch, GPL and attribution retained. Personal version 3.0.0/build300000; app display BoringNotch Personal, identifiers com.soakkk.BoringNotch and com.soakkk.BoringNotch.BoringNotchXPCHelper. Automatic updates use own HTTPS appcast and Ed25519 key only, with increasing builds and stable installation path. Mac has no Apple signing identity and no full Xcode; build on GitHub macOS runners and verify on this Mac. Keep sandbox and hardened runtime; document any necessary personal-signing limitation before installation.
