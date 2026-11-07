import SwiftUI

struct PersonalPanelLayout: Equatable {
    let musicWidth: CGFloat
    let artworkSize: CGFloat
    let agendaMinimumWidth: CGFloat
    static func resolve(isPlaying: Bool, hasItems: Bool, loading: Bool, denied: Bool) -> Self {
        if !hasItems && !loading && !denied {
            return Self(musicWidth: 340, artworkSize: 84, agendaMinimumWidth: 200)
        }
        return isPlaying
            ? Self(musicWidth: 264, artworkSize: 52, agendaMinimumWidth: 260)
            : Self(musicWidth: 216, artworkSize: 44, agendaMinimumWidth: 300)
    }
}

/// The approved lateral composition. Optional controls retain a full-width row
/// when their expanded footprint cannot fit alongside the artwork.
struct PersonalMusicLayout<Artwork: View, Metadata: View, Controls: View, Progress: View>: View {
    let artworkSize: CGFloat
    let controlsWidth: CGFloat
    let artwork: Artwork
    let metadata: (CGFloat) -> Metadata
    let controls: Controls
    let progress: Progress

    var body: some View {
        GeometryReader { geometry in
            let sideWidth = max(0, geometry.size.width - artworkSize - 14)
            let lateral = sideWidth >= max(120, controlsWidth)
            Group {
                if lateral {
                    VStack(spacing: 10) {
                        HStack(spacing: 14) {
                            artwork.frame(width: artworkSize, height: artworkSize)
                            VStack(alignment: .leading, spacing: 6) {
                                metadata(sideWidth)
                                controls
                            }.frame(width: sideWidth, height: 84, alignment: .leading)
                        }.frame(height: 84)
                        progress.frame(height: 28)
                    }
                } else {
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            artwork.frame(width: min(artworkSize, 52), height: min(artworkSize, 52))
                            metadata(max(0, geometry.size.width - min(artworkSize, 52) - 10))
                        }.frame(height: 56)
                        if controlsWidth > geometry.size.width {
                            ScrollView(.horizontal, showsIndicators: false) {
                                controls.frame(width: controlsWidth, height: 28, alignment: .leading)
                            }.frame(height: 28)
                        } else {
                            controls.frame(height: 28)
                        }
                        progress.frame(height: 28)
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }
}

struct PersonalSongMetadata: View {
    @Environment(\.personalTheme) private var theme
    let title: String
    let artist: String
    var titleLines: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.isEmpty ? "Tu música" : title)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(titleLines).fixedSize(horizontal: false, vertical: true)
            Text(artist.isEmpty ? "Elige algo para escuchar" : artist)
                .font(.system(size: 11.5)).foregroundStyle(theme.secondary).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).help(title + " · " + artist)
    }
}

/// Static native colors: skins never introduce a rendering clock or blur.
enum PersonalTheme: String, CaseIterable, Identifiable {
    case esencial, grafito, ambar
    var id: String { rawValue }
    var title: String {
        switch self { case .esencial: return "Esencial"; case .grafito: return "Grafito"; case .ambar: return "Ámbar" }
    }
    var detail: String {
        switch self {
        case .esencial: return "Negro y menta"
        case .grafito: return "Pizarra y azul hielo"
        case .ambar: return "Carbón cálido y ámbar"
        }
    }
    var surface: Color {
        switch self {
        case .esencial: return .black
        case .grafito: return Color(red: 0.075, green: 0.095, blue: 0.125)
        case .ambar: return Color(red: 0.115, green: 0.085, blue: 0.060)
        }
    }
    var accent: Color {
        switch self {
        case .esencial: return Color(red: 0.53, green: 0.89, blue: 0.75)
        case .grafito: return Color(red: 0.65, green: 0.80, blue: 0.98)
        case .ambar: return Color(red: 0.98, green: 0.76, blue: 0.46)
        }
    }
    var secondary: Color {
        switch self {
        case .esencial: return Color(red: 0.69, green: 0.74, blue: 0.72)
        case .grafito: return Color(red: 0.70, green: 0.76, blue: 0.83)
        case .ambar: return Color(red: 0.80, green: 0.73, blue: 0.65)
        }
    }
    var separator: Color { secondary.opacity(0.22) }
    var headingDesign: Font.Design { self == .grafito ? .rounded : .default }
    var artworkRadius: CGFloat { self == .grafito ? 10 : (self == .ambar ? 16 : 12) }
}

private struct PersonalThemeKey: EnvironmentKey {
    static let defaultValue = PersonalTheme.esencial
}
extension EnvironmentValues {
    var personalTheme: PersonalTheme {
        get { self[PersonalThemeKey.self] }
        set { self[PersonalThemeKey.self] = newValue }
    }
}

enum PersonalAgendaClock {
    static func selectedDay(after now: Date, previousNow: Date, selectedDay: Date, calendar: Calendar = .current) -> Date {
        guard !calendar.isDate(now, inSameDayAs: previousNow),
              calendar.isDate(selectedDay, inSameDayAs: previousNow) else { return selectedDay }
        return calendar.startOfDay(for: now)
    }
}
