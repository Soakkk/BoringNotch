//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan
//

import Combine
import Defaults
import SwiftUI

// MARK: - Music Player Components

struct MusicPlayerView: View {
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        HStack {
            AlbumArtView(vm: vm, albumArtNamespace: albumArtNamespace).padding(.all, 5)
            MusicControlsView()
        }
    }
}

struct AlbumArtView: View {
    @ObservedObject private var energy = PersonalEnergyManager.shared
    @Environment(\.personalTheme) private var theme
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if Defaults[.lightingEffect] && energy.allowsDecorativeAnimation {
                albumArtBackground
            }
            albumArtButton
        }
    }

    private var albumArtBackground: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: theme.artworkRadius)
            )
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(x: 1.3, y: 1.4)
            .rotationEffect(.degrees(92))
            .blur(radius: 40)
            .opacity(musicManager.isPlaying ? 0.5 : 0)
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                musicManager.openMusicApp()
            } label: {
                ZStack(alignment:.bottomTrailing) {
                    albumArtImage
                    appIconOverlay
                }
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(musicManager.isPlaying ? 1 : 0.82)
        }
    }

    private var albumArtImage: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: theme.artworkRadius)
            )
    }

    @ViewBuilder
    private var appIconOverlay: some View {
        if vm.notchState == .open && !musicManager.usingAppIconForArtwork {
            AppIcon(for: musicManager.bundleIdentifier ?? "com.apple.Music")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 16, height: 16)
                .offset(x: 3, y: 3)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
        }
    }
}

struct MusicControlsView: View {
    var albumArtNamespace: Namespace.ID? = nil
    var artworkSize: CGFloat = 52
    @ObservedObject private var energy = PersonalEnergyManager.shared
    @Environment(\.personalTheme) private var theme
    @ObservedObject var musicManager = MusicManager.shared
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast
    @Default(.musicControlSlots) private var slotConfig
    @Default(.musicControlSlotLimit) private var slotLimit

    var body: some View {
        Group {
            if let namespace = albumArtNamespace {
                PersonalMusicLayout(
                    artworkSize: artworkSize, controlsWidth: personalControlsWidth,
                    artwork: AlbumArtView(vm: vm, albumArtNamespace: namespace).accessibilityLabel("Abrir aplicación de música"),
                    metadata: { width in songInfo(width: width) },
                    controls: slotToolbar, progress: musicSlider
                )
            } else {
                // The camera's original side-by-side player keeps its existing sizing.
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        songInfo(width: geo.size.width).frame(maxHeight: .infinity, alignment: .center)
                    }.frame(height: artworkSize)
                    musicSlider
                    slotToolbar
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .tint(theme.accent)
    }

    private func songInfo(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: albumArtNamespace == nil ? 0 : 3) {
            if albumArtNamespace != nil {
                PersonalSongMetadata(title: musicManager.songTitle, artist: musicManager.artistName,
                                     titleLines: Defaults[.enableLyrics] ? 1 : 2)
            } else {
                MarqueeText(
                    Binding(get: { !musicManager.songTitle.isEmpty ? musicManager.songTitle : "Tu música" }, set: { _ in }), font: .headline, nsFont: .headline, textColor: .white,
                    frameWidth: width, isPlaying: musicManager.isPlaying && energy.allowsDecorativeAnimation)
                MarqueeText(
                    Binding(get: { !musicManager.artistName.isEmpty ? musicManager.artistName : "Elige algo para escuchar" }, set: { _ in }),
                    font: .subheadline,
                    nsFont: .subheadline,
                    textColor: theme.secondary,
                    frameWidth: width, isPlaying: musicManager.isPlaying && energy.allowsDecorativeAnimation
                )
                .fontWeight(.medium)
                .help(musicManager.songTitle + " · " + musicManager.artistName)
            }
            if Defaults[.enableLyrics] {
                TimelineView(.animation(minimumInterval: energy.progressInterval, paused: !musicManager.isPlaying || !energy.screenIsAwake)) { timeline in
                    let currentElapsed: Double = {
                        guard musicManager.isPlaying else { return musicManager.elapsedTime }
                        let delta = timeline.date.timeIntervalSince(musicManager.timestampDate)
                        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
                        return min(max(progressed, 0), musicManager.songDuration)
                    }()
                    let line: String = {
                        if musicManager.isFetchingLyrics { return "Cargando letra…" }
                        if !musicManager.syncedLyrics.isEmpty {
                            return musicManager.lyricLine(at: currentElapsed)
                        }
                        let trimmed = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? "No hay letra disponible" : trimmed.replacingOccurrences(of: "\n", with: " ")
                    }()
                    let isPersian = line.unicodeScalars.contains { scalar in
                        let v = scalar.value
                        return v >= 0x0600 && v <= 0x06FF
                    }
                    MarqueeText(
                        .constant(line),
                        font: .subheadline,
                        nsFont: .subheadline,
                        textColor: musicManager.isFetchingLyrics ? .gray.opacity(0.7) : .gray,
                        frameWidth: width, isPlaying: musicManager.isPlaying && energy.allowsDecorativeAnimation
                    )
                    .font(isPersian ? .custom("Vazirmatn-Regular", size: NSFont.preferredFont(forTextStyle: .subheadline).pointSize) : .subheadline)
                    .lineLimit(1)
                    .opacity(musicManager.isPlaying ? 1 : 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var musicSlider: some View {
        TimelineView(.animation(minimumInterval: energy.progressInterval, paused: !musicManager.isPlaying || musicManager.playbackRate <= 0 || !energy.screenIsAwake)) { timeline in
            MusicSliderView(
                sliderValue: $sliderValue,
                duration: $musicManager.songDuration,
                lastDragged: $lastDragged,
                color: musicManager.avgColor,
                dragging: $dragging,
                currentDate: timeline.date,
                timestampDate: musicManager.timestampDate,
                elapsedTime: musicManager.elapsedTime,
                playbackRate: musicManager.playbackRate,
                isPlaying: musicManager.isPlaying
            ) { newValue in
                MusicManager.shared.seek(to: newValue)
            }
            .frame(height: 28)
        }
    }

    private var slotToolbar: some View {
        let slots = albumArtNamespace == nil ? activeSlots : activeSlots.filter { $0 != .none }
        return HStack(spacing: 6) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                slotView(for: slot)
                    .frame(alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: albumArtNamespace == nil ? .center : .leading)
        .frame(height: albumArtNamespace == nil ? nil : 28)
    }

    private var personalControlsWidth: CGFloat {
        let slots = activeSlots.filter { $0 != .none }
        // Reserve the open volume slider too, so opening it never overflows the column.
        return CGFloat(slots.count * 28 + max(0, slots.count - 1) * 6 + slots.filter { $0 == .volume }.count * 48)
    }

    private var activeSlots: [MusicControlButton] {
        let sanitizedLimit = min(
            max(slotLimit, MusicControlButton.minSlotCount),
            MusicControlButton.maxSlotCount
        )
        let padded = slotConfig.padded(to: sanitizedLimit, filler: .none)
        let result = Array(padded.prefix(sanitizedLimit))
        // If calendar and camera are both visible alongside music, hide the edge slots
        let shouldHideEdges = Defaults[.showCalendar] && Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
        if shouldHideEdges && result.count >= 5 {
            return Array(result.dropFirst().dropLast())
        }

        return result
    }

    @ViewBuilder
    private func slotView(for slot: MusicControlButton) -> some View {
        switch slot {
        case .shuffle:
            HoverButton(icon: "shuffle", iconColor: musicManager.isShuffled ? .red : .primary, scale: .medium, compact: albumArtNamespace != nil) {
                MusicManager.shared.toggleShuffle()
            }
        case .previous:
            HoverButton(icon: "backward.fill", scale: .medium, compact: albumArtNamespace != nil) {
                MusicManager.shared.previousTrack()
            }
        case .playPause:
            HoverButton(icon: musicManager.isPlaying ? "pause.fill" : "play.fill", scale: .large, compact: albumArtNamespace != nil) {
                MusicManager.shared.togglePlay()
            }
        case .next:
            HoverButton(icon: "forward.fill", scale: .medium, compact: albumArtNamespace != nil) {
                MusicManager.shared.nextTrack()
            }
        case .repeatMode:
            HoverButton(icon: repeatIcon, iconColor: repeatIconColor, scale: .medium, compact: albumArtNamespace != nil) {
                MusicManager.shared.toggleRepeat()
            }
        case .volume:
            VolumeControlView()
        case .favorite:
            FavoriteControlButton(compact: albumArtNamespace != nil)
        case .goBackward:
            HoverButton(icon: "gobackward.15", scale: .medium, compact: albumArtNamespace != nil) {
                MusicManager.shared.skip(seconds: -15)
            }
        case .goForward:
            HoverButton(icon: "goforward.15", scale: .medium, compact: albumArtNamespace != nil) {
                MusicManager.shared.skip(seconds: 15)
            }
        case .none:
            Color.clear.frame(height: 1)
        }
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    private var repeatIconColor: Color {
        switch musicManager.repeatMode {
        case .off:
            return .primary
        case .all, .one:
            return .red
        }
    }
}

struct FavoriteControlButton: View {
    var compact: Bool = false
    @ObservedObject var musicManager = MusicManager.shared

    var body: some View {
        HoverButton(icon: iconName, iconColor: iconColor, scale: .medium, compact: compact) {
            MusicManager.shared.toggleFavoriteTrack()
        }
        .disabled(!musicManager.canFavoriteTrack)
        .opacity(musicManager.canFavoriteTrack ? 1 : 0.35)
    }

    private var iconName: String {
        musicManager.isFavoriteTrack ? "heart.fill" : "heart"
    }

    private var iconColor: Color {
        musicManager.isFavoriteTrack ? .red : .primary
    }
}

private extension Array where Element == MusicControlButton {
    func padded(to length: Int, filler: MusicControlButton) -> [MusicControlButton] {
        if count >= length { return self }
        return self + Array(repeating: filler, count: length - count)
    }
}

// MARK: - Volume Control View

struct VolumeControlView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @State private var volumeSliderValue: Double = 0.5
    @State private var dragging: Bool = false
    @State private var showVolumeSlider: Bool = false
    @State private var lastVolumeUpdateTime: Date = Date.distantPast
    private let volumeUpdateThrottle: TimeInterval = 0.1
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if musicManager.volumeControlSupported {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        showVolumeSlider.toggle()
                    }
                }
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(musicManager.volumeControlSupported ? .white : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!musicManager.volumeControlSupported)
            .frame(width: 24)

            if showVolumeSlider && musicManager.volumeControlSupported {
                CustomSlider(
                    value: $volumeSliderValue,
                    range: 0.0...1.0,
                    color: .white,
                    dragging: $dragging,
                    lastDragged: .constant(Date.distantPast),
                    onValueChange: { newValue in
                        MusicManager.shared.setVolume(to: newValue)
                    },
                    onDragChange: { newValue in
                        let now = Date()
                        if now.timeIntervalSince(lastVolumeUpdateTime) > volumeUpdateThrottle {
                            MusicManager.shared.setVolume(to: newValue)
                            lastVolumeUpdateTime = now
                        }
                    }
                )
                .frame(width: 48, height: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .clipped()
        .onReceive(musicManager.$volume) { volume in
            if !dragging {
                volumeSliderValue = volume
            }
        }
        .onReceive(musicManager.$volumeControlSupported) { supported in
            if !supported {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showVolumeSlider = false
                }
            }
        }
        .onChange(of: showVolumeSlider) { _, isShowing in
            if isShowing {
                // Sync volume from app when slider appears
                Task {
                    await MusicManager.shared.syncVolumeFromActiveApp()
                }
            }
        }
        .onDisappear {
            // volumeUpdateTask?.cancel() // No longer needed
        }
    }
    
    
    private var volumeIcon: String {
        if !musicManager.volumeControlSupported {
            return "speaker.slash"
        } else if volumeSliderValue == 0 {
            return "speaker.slash.fill"
        } else if volumeSliderValue < 0.33 {
            return "speaker.1.fill"
        } else if volumeSliderValue < 0.66 {
            return "speaker.2.fill"
        } else {
            return "speaker.3.fill"
        }
    }
}

// MARK: - Main View

struct NotchHomeView: View {
    @AppStorage("personalTheme") private var theme: PersonalTheme = .esencial
    @ObservedObject private var energy = PersonalEnergyManager.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @Default(.showCalendar) private var showCalendar
    @State private var agendaNow = Date()
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    let albumArtNamespace: Namespace.ID
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var agendaDetail = false
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    var body: some View {
        Group {
            if !coordinator.firstLaunch {
                personalContent
            }
        }
        .environment(\.personalTheme, theme)
        .transition(.opacity)
        .task(id: energy.screenIsAwake && showCalendar) {
            guard energy.screenIsAwake && showCalendar else { return }
            refreshAgendaClock()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                refreshAgendaClock()
            }
        }
    }

    @ViewBuilder private var personalContent: some View {
        if shouldShowCamera { mainContent }
        else if !showCalendar { MusicControlsView(albumArtNamespace: albumArtNamespace, artworkSize: 84).frame(height: 128) }
        else {
            HStack(spacing: 16) {
                if !agendaDetail {
                    MusicControlsView(albumArtNamespace: albumArtNamespace, artworkSize: panelLayout.artworkSize)
                        .frame(width: panelLayout.musicWidth, height: 128)
                    Rectangle().fill(theme.separator).frame(width: 1, height: 116)
                }
                PersonalAgendaSurface(
                    heading: agendaHeading, items: agendaItems,
                    detailed: agendaDetail, loading: agendaLoading,
                    denied: agendaDenied,
                    onBack: { agendaDetail = false }, onDetail: { agendaDetail = true },
                    onPrevious: { changeDay(-1) }, onNext: { changeDay(1) },
                    onToday: { selectedDate = Calendar.current.startOfDay(for: Date()) },
                    onOpen: { id in
                        guard let event = calendarManager.events.first(where: { $0.id == id }) else { return }
                        if !agendaDetail { agendaDetail = true }
                        else if let url = event.calendarAppURL() { NSWorkspace.shared.open(url) }
                    },
                    onReminder: { id, completed in Task { await calendarManager.setReminderCompleted(reminderID: id, completed: completed) } },
                    onSettings: { SettingsWindowController.shared.showWindow() }
                )
                .onHover { vm.isHoveringCalendar = $0 }
            }
            .frame(height: 128)
            .task(id: selectedDate) { await calendarManager.updateCurrentDate(selectedDate) }
        }
    }

    private var agendaDenied: Bool {
        calendarManager.calendarAuthorizationStatus != .fullAccess && calendarManager.reminderAuthorizationStatus != .fullAccess
    }
    private var agendaLoading: Bool {
        calendarManager.isLoading || !Calendar.current.isDate(selectedDate, inSameDayAs: calendarManager.currentWeekStartDate)
    }
    private var panelLayout: PersonalPanelLayout {
        PersonalPanelLayout.resolve(isPlaying: musicManager.isPlaying, hasItems: !agendaItems.isEmpty,
                                    loading: agendaLoading, denied: agendaDenied)
    }
    private func refreshAgendaClock() {
        let now = Date()
        selectedDate = PersonalAgendaClock.selectedDay(after: now, previousNow: agendaNow, selectedDay: selectedDate)
        agendaNow = now
    }
    private var agendaHeading: String {
        let prefix = Calendar.current.isDateInToday(selectedDate) ? "Hoy · " : ""
        return prefix + selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).capitalized
    }
    private var agendaItems: [PersonalAgendaItem] {
        let events = EventListView.filteredEvents(events: calendarManager.events).sorted { $0.start < $1.start }
        let candidates = !agendaDetail && Calendar.current.isDateInToday(selectedDate)
            ? events.filter { $0.isAllDay || $0.end > agendaNow || $0.type.isReminder } : events
        return candidates.map { event in
            let time = event.isAllDay ? "Todo el día" : event.start.formatted(date: .omitted, time: .shortened)
            let end = event.isAllDay ? "" : event.end.formatted(date: .omitted, time: .shortened)
            let duration = max(0, Int(event.end.timeIntervalSince(event.start) / 60))
            let subtitle = event.isAllDay ? event.calendar.title : "\(event.calendar.title) · \(duration) min"
            let completed: Bool? = { if case .reminder(let done) = event.type { return done }; return nil }()
            return PersonalAgendaItem(id: event.id, time: time, endTime: end, title: event.title,
                subtitle: subtitle, color: Color(nsColor: event.calendar.color), completed: completed)
        }
    }
    private func changeDay(_ offset: Int) {
        if let day = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) { selectedDate = day }
    }

    private var shouldShowCamera: Bool {
        Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: (shouldShowCamera && Defaults[.showCalendar]) ? 10 : 15) {
            MusicPlayerView(albumArtNamespace: albumArtNamespace)

            if Defaults[.showCalendar] {
                CalendarView()
                    .frame(width: shouldShowCamera ? 170 : 215)
                    .onHover { isHovering in
                        vm.isHoveringCalendar = isHovering
                    }
                    .environmentObject(vm)
                    .transition(.opacity)
            }

            if shouldShowCamera {
                CameraPreviewView(webcamManager: webcamManager)
                    .scaledToFit()
                    .opacity(vm.notchState == .closed ? 0 : 1)
                    .blur(radius: vm.notchState == .closed ? 20 : 0)
                    .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.76, blendDuration: 0), value: shouldShowCamera)
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        .blur(radius: vm.notchState == .closed ? 30 : 0)
    }
}

struct MusicSliderView: View {
    @Environment(\.personalTheme) private var theme
    @Binding var sliderValue: Double
    @Binding var duration: Double
    @Binding var lastDragged: Date
    var color: NSColor
    @Binding var dragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    var onValueChange: (Double) -> Void


    var body: some View {
        VStack {
            CustomSlider(
                value: $sliderValue,
                range: 0...duration,
                color: Defaults[.sliderColor] == .albumArt
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.8)
                    : Defaults[.sliderColor] == .accent ? .effectiveAccent : theme.accent,
                dragging: $dragging,
                lastDragged: $lastDragged,
                onValueChange: onValueChange
            )
            .frame(height: 10, alignment: .center)

            HStack {
                Text(timeString(from: sliderValue))
                Spacer()
                Text(timeString(from: duration))
            }
            .fontWeight(.medium)
            .foregroundColor(theme.secondary)
            .font(.caption)
        }
        .onAppear { updatePosition() }
        .onChange(of: currentDate) { updatePosition() }
        .onChange(of: elapsedTime) { updatePosition() }
        .onChange(of: duration) { updatePosition() }
        .onChange(of: isPlaying) { updatePosition() }
    }

    private func updatePosition() {
        guard !dragging, timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
        sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
    }

    func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .white
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var onDragChange: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 9 : 5)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: filledTrackWidth, height: height)
            }
            .cornerRadius(height / 2)
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation {
                            dragging = true
                        }
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        dragging = false
                        lastDragged = Date()
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragging)
        }
    }
}

// MARK: - Personal agenda surface
// Pure value-driven view, also rendered by the isolated native fixture harness.
struct PersonalAgendaItem: Identifiable {
    let id: String
    let time: String
    let endTime: String
    let title: String
    let subtitle: String
    let color: Color
    var completed: Bool? = nil
}

struct PersonalAgendaSurface: View {
    @Environment(\.personalTheme) private var theme
    let heading: String
    let items: [PersonalAgendaItem]
    let detailed: Bool
    let loading: Bool
    let denied: Bool
    let onBack: () -> Void
    let onDetail: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    let onOpen: (String) -> Void
    let onReminder: (String, Bool) -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                if detailed { icon("chevron.left", "Volver a música", action: onBack) }
                Button(action: onDetail) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.system(size: 12)).foregroundStyle(theme.accent)
                        Text(heading).font(.system(size: 12, weight: .semibold, design: theme.headingDesign)).lineLimit(1)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).help("Ver la agenda completa sin ampliar el notch")
                Spacer(minLength: 0)
                icon("chevron.left", "Día anterior", action: onPrevious)
                icon("circle.fill", "Volver a hoy", action: onToday)
                icon("chevron.right", "Día siguiente", action: onNext)
            }.frame(height: 22)
            if denied {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Permite el acceso al calendario").font(.system(size: 12, weight: .medium))
                    Button("Abrir ajustes", action: onSettings).buttonStyle(.plain).foregroundStyle(theme.accent)
                }.frame(maxHeight: .infinity, alignment: .center)
            } else if loading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Cargando agenda…").font(.system(size: 12)) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sin eventos pendientes").font(.system(size: 13, weight: .semibold))
                    Text("Consulta otro día").font(.system(size: 11)).foregroundStyle(theme.secondary)
                    if !detailed { Button("Ver el día completo", action: onDetail).buttonStyle(.plain).foregroundStyle(theme.accent).font(.system(size: 11)) }
                }.frame(maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(.vertical, showsIndicators: detailed) {
                    LazyVStack(alignment: .leading, spacing: detailed ? 5 : 3) {
                        ForEach(detailed ? items : Array(items.prefix(3))) { item in
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.time)
                                    if detailed && !item.endTime.isEmpty { Text(item.endTime).foregroundStyle(theme.secondary) }
                                }.font(.system(size: detailed ? 12 : 11, weight: .medium)).monospacedDigit()
                                    .frame(width: detailed ? 52 : 46, alignment: .leading)
                                if let completed = item.completed {
                                    Button { onReminder(item.id, !completed) } label: {
                                        Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.color).frame(width: 16, height: 26)
                                    }.buttonStyle(.plain).accessibilityLabel(completed ? "Marcar recordatorio pendiente" : "Completar recordatorio")
                                } else { RoundedRectangle(cornerRadius: 1.5).fill(item.color).frame(width: 3, height: 24) }
                                Button { onOpen(item.id) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.system(size: detailed ? 13 : 12, weight: .semibold))
                                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                        if detailed || item.title.count < 30 {
                                            Text(item.subtitle).font(.system(size: 10)).foregroundStyle(theme.secondary).lineLimit(1)
                                        }
                                    }.frame(maxWidth: .infinity, minHeight: detailed ? 39 : 30, alignment: .leading)
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).help(item.title)
                            }.accessibilityElement(children: .contain)
                            if detailed { Rectangle().fill(theme.separator).frame(height: 0.5) }
                        }
                    }
                }
            }
        }.foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func icon(_ name: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name).font(.system(size: name == "circle.fill" ? 5 : 11, weight: .semibold)).frame(width: 20, height: 22).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityLabel(label).help(label)
    }
}
