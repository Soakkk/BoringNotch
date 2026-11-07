import AppKit
import SwiftUI

@main struct SegmentedHUDTests {
    static var failures = 0
    static func check(_ passes: @autoclosure () -> Bool, _ name: String) {
        if passes() { print("PASS: \(name)") }
        else { failures += 1; print("FAIL: \(name)") }
    }

    @MainActor static func main() throws {
        check(SegmentedLevel.litCount(0) == 0, "mute leaves all twenty segments inactive")
        check(SegmentedLevel.litCount(1) == 20, "full level lights all twenty segments")
        check(SegmentedLevel.litCount(0.56) == 12, "normal level uses the approved twenty-step display")
        check(SegmentedLevel.litCount(0.001) == 1, "a small positive level remains visible")
        check(SegmentedLevel.normalized(-1) == 0 && SegmentedLevel.normalized(2) == 1, "external levels are bounded")
        check(SegmentedLevel.normalized(.nan) == 0 && SegmentedLevel.normalized(.infinity) == 0, "invalid readings cannot poison view geometry")
        check(SegmentedLevel.dragValue(at: 52.5, width: 100) == 0.525, "dragging preserves fractions instead of snapping to segments")
        check(SegmentedLevel.dragValue(at: -12, width: 100) == 0, "dragging beyond the left edge reaches zero")
        check(SegmentedLevel.dragValue(at: 112, width: 100) == 1, "dragging beyond the right edge reaches full level")
        check(SegmentedLevel.dragValue(at: 20, width: 0) == nil, "zero-width layout never changes the device")
        check(SegmentedLevel.dragValue(at: .nan, width: 100) == nil && SegmentedLevel.dragValue(at: 20, width: .infinity) == nil, "non-finite drag geometry is ignored")

        var received: [CGFloat] = []
        var writes: [CGFloat] = []
        var level: CGFloat = 0.4
        let binding = Binding(get: { level }, set: { level = $0; writes.append($0) })
        SegmentedLevel.commit(0.525, to: binding, onChange: { received.append($0) })
        check(level == 0.525 && received == [0.525] && writes == [0.525], "one interaction updates the binding and device callback exactly once")
        SegmentedLevel.commit(.nan, to: binding, onChange: { received.append($0) })
        check(level == 0.525 && received.count == 1, "invalid input never reaches the device callback")
        SegmentedLevel.commit(2, to: binding, onChange: { received.append($0) })
        check(level == 1 && received.last == 1, "accessibility adjustment remains bounded")

        NSApplication.shared.setActivationPolicy(.accessory)
        let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/boring-segmented-hud-renders")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for compact in [false, true] {
            for value in [CGFloat(0), 0.56, 1] {
                let width: CGFloat = compact ? 156 : 320
                let root = SegmentedHUD(value: .constant(value), label: value == 0 ? "Volumen" : "Brillo",
                    symbol: value == 0 ? "speaker.slash.fill" : "sun.max.fill",
                    showPercentage: true, compact: compact, animationEnabled: false)
                    .padding(.horizontal, compact ? 10 : 16).padding(.vertical, compact ? 4 : 10)
                    .frame(width: width).background(Color(red: 0.09, green: 0.10, blue: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 15 : 25))
                    .preferredColorScheme(.dark)
                let renderer = ImageRenderer(content: root)
                renderer.scale = 2
                guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Native rendering failed") }
                check(image.size.width == width && image.size.height <= (compact ? 32 : 58), "\(compact ? "compact" : "standard") \(Int(value * 100))% stays inside the HUD footprint")
                try png.write(to: directory.appendingPathComponent("\(compact ? "compact" : "standard")-\(Int(value * 100)).png"))
            }
        }
        let inline = SegmentedLevelBar(value: .constant(0.56), animationEnabled: false, accessibilityLabel: "Volumen")
            .frame(width: 65, height: 7).padding(4).background(.black).preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: inline)
        renderer.scale = 4
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Inline rendering failed") }
        try png.write(to: directory.appendingPathComponent("inline-65pt.png"))
        check(image.size.width == 73, "all twenty segments fit the narrow inline meter")
        if failures > 0 { exit(1) }
        print("Segmented HUD: 21 checks passed; 7 native fixtures in \(directory.path)")
    }
}
