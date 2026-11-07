# BoringNotch Personal 3.1 — adaptive compact experience

The user selected intelligent minimum energy use, adaptive music/agenda space, three themed skins and a Spanish-language pass. Execution continues in the existing dedicated clean clone, on a feature branch. Existing authorization covers own GitHub updates, install/restart and app-only library validation exception; retain sandbox and signed feed/archive. App remains separate from FocusNotch.

Keep open content 640×190pt and host640×210pt. The panel hides normally; no pinning, new calendar actions or shelf/file-drag changes. Agenda remains a short list of up to three items, with existing same-sized detail.

Adaptive layout: when calendar access is available, fetch is finished and the selected day has no pending items, give music more horizontal space and keep a compact empty agenda with navigation. If events exist and music is paused/inactive, keep a smaller usable player and widen agenda. While playing with events use balanced proportions. Permission/loading states must never be mistaken for an empty day. Retain all essential player controls, do not remove player for pause, avoid oscillating widths or expansion beyond640pt.

Skins: implementation choice is Esencial (black/mint), Grafito (slate/icy blue), Ámbar (warm charcoal/amber). Persistent settings selector, coherent static surfaces/accents/typography, legible contrast, calendar-source colors preserved, actual notch center stays black. No perpetual theme effects or new rendering framework.

Energy: adaptive saving ON by default. Battery, OS Low Power, thermal pressure or Reduce Motion disable decorative loops/blur; sleep/locked display pauses UI work. Playing visible progress may refresh at1s in saving versus0.5s normally; paused timelines stop. Keep correct playback through timestamp extrapolation and provider notifications. Audit controller polling for bounded rates, no overlapping work and unchanged-state emissions. Calendars refresh on real changes/navigation/open and a low-frequency visible schedule for current-event boundaries/day rollover. Preserve playback commands and accurate event dates.

Spanish: fill user-visible Spanish translation gaps and fix dynamic untranslated labels in touched settings/media/battery paths. Product names, actual song/event content and protocol/technical identifiers are not translated. No blanket rewrite of shelf logic.

Deliver signed universal macOS15+ version3.1.0/build301000 through existing own Sparkle feed; check native renders for every skin/layout, behavioral energy/layout tests, calendar ordering and decorative lifecycle regressions, CI build, public signature/hash checks, one installed app and actual update check. CPU measurements are short observations, not promised battery-life percentages.
