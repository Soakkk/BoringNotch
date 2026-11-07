import SwiftUI

struct PersonalPanelLayout: Equatable {
    let musicWidth: CGFloat
    let artworkSize: CGFloat
    let agendaMinimumWidth: CGFloat
    static func resolve(isPlaying: Bool, hasItems: Bool, loading: Bool, denied: Bool) -> Self {
        if !hasItems && !loading && !denied {
            return Self(musicWidth: 340, artworkSize: 60, agendaMinimumWidth: 200)
        }
        return isPlaying
            ? Self(musicWidth: 264, artworkSize: 52, agendaMinimumWidth: 260)
            : Self(musicWidth: 216, artworkSize: 44, agendaMinimumWidth: 300)
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
