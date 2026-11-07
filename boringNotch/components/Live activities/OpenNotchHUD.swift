// Original open HUD by Alexander (2024); segmented presentation for Personal (2026).
import SwiftUI
import Defaults

struct OpenNotchHUD: View {
    @Binding var type: SneakContentType
    @Binding var value: CGFloat
    @Binding var icon: String
    @Default(.showOpenNotchHUDPercentage) var showPercentage
    @ObservedObject private var energy = PersonalEnergyManager.shared

    var body: some View {
        Group {
            if type == .mic {
                HStack(spacing: 8) {
                    Image(systemName: type.hudSymbol(value: value, customIcon: icon))
                    Text(LocalizedStringKey(value > 0 ? "Unmuted" : "Muted"))
                        .font(.system(size: 13, weight: .medium)).fixedSize()
                }.foregroundStyle(.white).padding(.vertical, 6)
            } else {
                SegmentedHUD(value: $value, label: type.hudLabel,
                    symbol: type.hudSymbol(value: value, customIcon: icon),
                    showPercentage: showPercentage, compact: true,
                    tint: Defaults[.systemEventIndicatorUseAccent] ? .effectiveAccent : .white,
                    gradient: Defaults[.enableGradient], glow: Defaults[.systemEventIndicatorShadow],
                    animationEnabled: energy.allowsDecorativeAnimation, onChange: updateSystemValue)
                    .frame(width: 136).padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.black).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func updateSystemValue(_ value: CGFloat) {
        switch type {
        case .volume: VolumeManager.shared.setAbsolute(Float32(value))
        case .brightness: BrightnessManager.shared.setAbsolute(value: Float32(value))
        case .backlight: KeyboardBacklightManager.shared.setAbsolute(value: Float32(value))
        default: break
        }
    }
}
