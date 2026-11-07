import SwiftUI

enum SegmentedLevel {
    static let count = 20
    static func normalized(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
    static func litCount(_ value: CGFloat) -> Int {
        Int(ceil(normalized(value) * CGFloat(count)))
    }
    static func dragValue(at location: CGFloat, width: CGFloat) -> CGFloat? {
        guard location.isFinite, width.isFinite, width > 0 else { return nil }
        return normalized(location / width)
    }
    static func commit(_ value: CGFloat, to binding: Binding<CGFloat>, onChange: ((CGFloat) -> Void)?) {
        guard value.isFinite else { return }
        let next = normalized(value)
        binding.wrappedValue = next
        onChange?(next)
    }
}

/// Twenty visual steps, with continuous device input and no idle animation work.
struct SegmentedLevelBar: View {
    @Binding var value: CGFloat
    var height: CGFloat = 7
    var tint: Color = .white
    var gradient = false
    var glow = false
    var animationEnabled = true
    var accessibilityLabel = ""
    var onChange: ((CGFloat) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false
    private var animates: Bool { animationEnabled && !reduceMotion && !isDragging }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: max(1, min(3, geometry.size.width / 85))) {
                ForEach(0..<SegmentedLevel.count, id: \.self) { index in
                    let lit = index < SegmentedLevel.litCount(value)
                    RoundedRectangle(cornerRadius: min(2.5, height / 3), style: .continuous)
                        .fill(segmentFill(lit: lit))
                        .scaleEffect(x: 1, y: lit ? 1 : 0.8)
                        .animation(animates ? .easeOut(duration: 0.15).delay(Double(index) * 0.003) : nil, value: lit)
                }
            }
            .shadow(color: glow && animationEnabled && !reduceMotion ? tint.opacity(0.3) : .clear,
                    radius: 3, x: 0, y: 1)
            .contentShape(Rectangle().inset(by: -6))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    isDragging = true
                    guard let next = SegmentedLevel.dragValue(at: gesture.location.x, width: geometry.size.width) else { return }
                    SegmentedLevel.commit(next, to: $value, onChange: onChange)
                }
                .onEnded { _ in isDragging = false })
        }
        .frame(height: height)
        .transaction { transaction in
            if !animationEnabled || reduceMotion || isDragging {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text("\(Int(SegmentedLevel.normalized(value) * 100))%"))
        .accessibilityAdjustableAction { direction in
            let delta: CGFloat
            switch direction {
            case .increment: delta = 0.05
            case .decrement: delta = -0.05
            @unknown default: return
            }
            SegmentedLevel.commit(SegmentedLevel.normalized(value) + delta, to: $value, onChange: onChange)
        }
    }

    private func segmentFill(lit: Bool) -> AnyShapeStyle {
        guard lit else { return AnyShapeStyle(Color.white.opacity(0.12)) }
        if gradient {
            return AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(tint.opacity(0.92))
    }
}

struct SegmentedHUD: View {
    @Binding var value: CGFloat
    let label: String
    let symbol: String
    var showPercentage = true
    var compact = false
    var tint: Color = .white
    var gradient = false
    var glow = false
    var animationEnabled = true
    var onChange: ((CGFloat) -> Void)? = nil

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 10 : 12, weight: .medium))
                    .frame(width: compact ? 12 : 14)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .lineLimit(1).help(label)
                Spacer(minLength: 4)
                if showPercentage {
                    Text("\(Int(SegmentedLevel.normalized(value) * 100))%")
                        .font(.system(size: compact ? 10 : 11, weight: .medium))
                        .monospacedDigit().fixedSize()
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.white.opacity(0.92))
            .frame(height: compact ? 12 : 14)
            SegmentedLevelBar(value: $value, height: compact ? 5 : 8, tint: tint,
                gradient: gradient, glow: glow, animationEnabled: animationEnabled,
                accessibilityLabel: label, onChange: onChange)
        }
    }
}
