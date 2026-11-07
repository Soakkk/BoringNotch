import AppKit
import SwiftUI

struct MusicFixture: View {
    let theme: PersonalTheme
    let mode: String
    var width: CGFloat { mode == "empty" ? 340 : (mode == "playing" ? 264 : 216) }
    var artworkSize: CGFloat { mode == "empty" ? 84 : (mode == "playing" ? 52 : 44) }
    var controlsWidth: CGFloat { mode == "volume" ? 212 : (mode == "slots" ? 164 : 96) }
    var symbols: [String] {
        if mode == "slots" || mode == "volume" { return ["shuffle", "backward.fill", "play.fill", "forward.fill", mode == "volume" ? "speaker.wave.2.fill" : "repeat"] }
        return ["backward.fill", mode == "playing" ? "pause.fill" : "play.fill", "forward.fill"]
    }
    var body: some View {
        PersonalMusicLayout(artworkSize: artworkSize, controlsWidth: controlsWidth,
            artwork: RoundedRectangle(cornerRadius: theme.artworkRadius).fill(Color(red: 0.63, green: 0.04, blue: 0.13))
                .overlay(Image(systemName: "music.note").font(.system(size: 24)).foregroundStyle(.white)),
            metadata: { _ in
                VStack(alignment: .leading, spacing: 3) {
                    PersonalSongMetadata(title: "Little Bad Girl (feat. Taio Cruz & Ludacris)", artist: "David Guetta · artista invitado con un nombre largo", titleLines: mode == "lyrics" ? 1 : 2)
                    if mode == "lyrics" { Text("Una línea de letra bastante larga…").font(.subheadline).foregroundStyle(theme.secondary).lineLimit(1) }
                }
            },
            controls: HStack(spacing: 6) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    HoverButton(icon: symbol, scale: symbol == "play.fill" || symbol == "pause.fill" ? .large : .medium, compact: true) {}
                    if symbol == "speaker.wave.2.fill" { Capsule().fill(theme.accent).frame(width: 42, height: 3) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading),
            progress: VStack(spacing: 5) {
                Capsule().fill(theme.secondary.opacity(0.25)).frame(height: 3)
                HStack { Text("0:04"); Spacer(); Text("3:04") }.font(.caption).foregroundStyle(theme.secondary)
            }
        ).frame(width: width, height: 128).environment(\.personalTheme, theme)
            .foregroundStyle(.white).environment(\.colorScheme, .dark).padding(16).background(theme.surface)
    }
}

@main struct MusicLayoutRender {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let modes = ["empty", "playing", "paused", "lyrics", "slots", "volume"]
        func render<V: View>(_ view: V, name: String) throws {
            let renderer = ImageRenderer(content: view); renderer.scale = 2
            let bitmap = NSBitmapImageRep(data: renderer.nsImage!.tiffRepresentation!)!
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
        }
        for theme in PersonalTheme.allCases {
            for mode in modes { try render(MusicFixture(theme: theme, mode: mode), name: "\(theme.rawValue)-\(mode).png") }
        }
        let sheet = VStack(alignment: .leading, spacing: 16) {
            ForEach(PersonalTheme.allCases) { theme in
                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.title).font(.headline)
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(modes, id: \.self) { mode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode).font(.caption)
                                MusicFixture(theme: theme, mode: mode)
                            }
                        }
                    }
                }
            }
        }.padding(20).foregroundStyle(.white).background(.black)
        try render(sheet, name: "matrix.png")
        print("Rendered 18 production-layout fixtures: three themes, wide/playing/paused/lyrics/five controls/expanded volume.")
    }
}
