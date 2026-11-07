import AppKit
import SwiftUI

@main struct AgendaRenderTests {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1]); try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let items = [
            PersonalAgendaItem(id: "a", time: "09:00", endTime: "10:00", title: "Gestión financiera: análisis de balances y ejercicios", subtitle: "Clase · 60 min", color: .mint),
            PersonalAgendaItem(id: "b", time: "11:30", endTime: "12:15", title: "Repaso de contabilidad y actividades pendientes", subtitle: "Personal · 45 min", color: .blue),
            PersonalAgendaItem(id: "c", time: "Todo el día", endTime: "", title: "Entrega de práctica", subtitle: "Calendario personal", color: .orange, completed: false)
        ]
        for theme in PersonalTheme.allCases {
        for state in ["summary", "paused", "detail", "empty", "denied", "loading"] {
            var actions = [String]()
            let detailed = state == "detail"
            let layout = PersonalPanelLayout.resolve(isPlaying: state != "paused", hasItems: state != "empty", loading: state == "loading", denied: state == "denied")
            let surface = PersonalAgendaSurface(heading: "Hoy · Sáb 7 nov", items: state == "empty" ? [] : items,
                detailed: detailed, loading: state == "loading", denied: state == "denied",
                onBack: { actions.append("back") }, onDetail: { actions.append("detail") },
                onPrevious: { actions.append("previous") }, onNext: { actions.append("next") },
                onToday: { actions.append("today") }, onOpen: { actions.append($0) },
                onReminder: { _, _ in actions.append("reminder") }, onSettings: { actions.append("settings") })
            let root = VStack(spacing: 6) {
                HStack { Image(systemName: "house"); Spacer(); Image(systemName: "gear"); Text("80%") }.font(.system(size: 11)).frame(height: 28)
                HStack(spacing: 16) {
                    if !detailed {
                        PersonalMusicLayout(artworkSize: layout.artworkSize, controlsWidth: 96,
                            artwork: RoundedRectangle(cornerRadius: theme.artworkRadius)
                                    .fill(theme.accent.opacity(0.16))
                                    .overlay(Image(systemName: "music.note").font(.system(size: 22)).foregroundStyle(theme.accent)),
                            metadata: { _ in PersonalSongMetadata(title: "Night Walk", artist: "Ambient Sessions") },
                            controls: HStack(spacing: 6) {
                                HoverButton(icon: "backward.fill", compact: true) {}
                                HoverButton(icon: state == "paused" ? "play.fill" : "pause.fill", scale: .large, compact: true) {}
                                HoverButton(icon: "forward.fill", compact: true) {}
                            }.frame(maxWidth: .infinity, alignment: .leading),
                            progress: VStack(spacing: 5) {
                                Capsule().fill(theme.accent).frame(height: 3)
                                HStack { Text("1:24"); Spacer(); Text("4:32") }.font(.system(size: 10)).foregroundStyle(theme.secondary)
                            }
                        ).frame(width: layout.musicWidth, height: 128)
                        Rectangle().fill(theme.separator).frame(width: 1, height: 116)
                    }
                    surface
                }.frame(height: 128)
                Spacer(minLength: 0)
            }.padding(.horizontal, 31).padding(.bottom, 12).frame(width: 640, height: 190).environment(\.personalTheme, theme).foregroundStyle(.white).background(theme.surface).clipShape(RoundedRectangle(cornerRadius: 24)).preferredColorScheme(.dark)
            let host = NSHostingView(rootView: root); host.sizingOptions = []; host.frame = NSRect(x: 0,y: 0,width: 640,height: 190)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false); window.contentView = host; window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            precondition(host.bounds.size == NSSize(width: 640,height: 190), "Every state preserves the approved footprint")
            let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!; host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(theme.rawValue)-\(state).png"))
            window.orderOut(nil)
        }
        }
        print("18 native theme/layout fixtures rendered at640×190; long titles, all-day/reminder, paused, empty, denied and loading fit")
    }
}
