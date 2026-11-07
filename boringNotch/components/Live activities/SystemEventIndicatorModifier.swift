// Original HUD by Richard Kunkli (2024); segmented presentation for Personal (2026).
import SwiftUI
import Defaults

extension SneakContentType {
    var hudLabel: String {
        switch self {
        case .volume: String(localized: "Volume")
        case .brightness: String(localized: "Brightness")
        case .backlight: String(localized: "Backlight")
        case .mic: String(localized: "Mic")
        default: ""
        }
    }

    func hudSymbol(value: CGFloat, customIcon: String) -> String {
        switch self {
        case .volume:
            if !customIcon.isEmpty { return customIcon }
            switch SegmentedLevel.normalized(value) {
            case 0: return "speaker.slash.fill"
            case ...0.33: return "speaker.wave.1.fill"
            case ...0.66: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        case .brightness: return "sun.max.fill"
        case .backlight: return value > 0.5 ? "light.max" : "light.min"
        case .mic: return value > 0 ? "mic.fill" : "mic.slash.fill"
        default: return "circle"
        }
    }
}

struct SystemEventIndicatorModifier: View {
    @Binding var eventType: SneakContentType
    @Binding var value: CGFloat
    @Binding var icon: String
    var sendEventBack: (CGFloat) -> Void
    @ObservedObject private var energy = PersonalEnergyManager.shared

    var body: some View {
        Group {
            if eventType == .mic {
                HStack(spacing: 14) {
                    Image(systemName: eventType.hudSymbol(value: value, customIcon: icon))
                    Text("Mic \(value > 0 ? String(localized: "unmuted") : String(localized: "muted"))")
                        .foregroundStyle(.gray).lineLimit(1)
                }.foregroundStyle(.white)
            } else {
                SegmentedHUD(value: $value, label: eventType.hudLabel,
                    symbol: eventType.hudSymbol(value: value, customIcon: icon),
                    showPercentage: Defaults[.showClosedNotchHUDPercentage],
                    tint: Defaults[.systemEventIndicatorUseAccent] ? .effectiveAccent : .white,
                    gradient: Defaults[.enableGradient], glow: Defaults[.systemEventIndicatorShadow],
                    animationEnabled: energy.allowsDecorativeAnimation, onChange: sendEventBack)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Retains the inline HUD's existing geometry and continuous input contract.
struct DraggableProgressBar: View {
    @Binding var value: CGFloat
    var onChange: ((CGFloat) -> Void)? = nil
    var accessibilityLabel = ""
    @ObservedObject private var energy = PersonalEnergyManager.shared

    var body: some View {
        SegmentedLevelBar(value: $value, height: Defaults[.inlineHUD] ? 5 : 7,
            tint: Defaults[.systemEventIndicatorUseAccent] ? .effectiveAccent : .white,
            gradient: Defaults[.enableGradient], glow: Defaults[.systemEventIndicatorShadow],
            animationEnabled: energy.allowsDecorativeAnimation,
            accessibilityLabel: accessibilityLabel, onChange: onChange)
    }
}
