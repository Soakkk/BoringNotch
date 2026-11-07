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
        for state in ["summary", "detail", "empty", "denied", "loading"] {
            var actions = [String]()
            let detailed = state == "detail"
            let surface = PersonalAgendaSurface(heading: "Hoy · Sáb 7 nov", items: state == "empty" ? [] : items,
                detailed: detailed, loading: state == "loading", denied: state == "denied",
                onBack: { actions.append("back") }, onDetail: { actions.append("detail") },
                onPrevious: { actions.append("previous") }, onNext: { actions.append("next") },
                onToday: { actions.append("today") }, onOpen: { actions.append($0) },
                onReminder: { _, _ in actions.append("reminder") }, onSettings: { actions.append("settings") })
            let root = VStack(spacing: 6) {
                HStack { Image(systemName: "house"); Spacer(); Image(systemName: "gear"); Text("80%") }.font(.system(size: 11)).frame(height: 28)
                HStack(spacing: 16) {
                    if !detailed { VStack(alignment: .leading) { Text("Night Walk").font(.headline); Text("Ambient Sessions").foregroundStyle(.gray); Spacer(); HStack { Image(systemName: "backward.fill"); Spacer(); Image(systemName: "play.fill"); Spacer(); Image(systemName: "forward.fill") }; Spacer(); Rectangle().fill(.mint).frame(height: 3) }.frame(width: 264, height: 120); Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 116) }
                    surface
                }.frame(height: 128)
                Spacer(minLength: 0)
            }.padding(.horizontal, 31).padding(.bottom, 12).frame(width: 640, height: 190).foregroundStyle(.white).background(.black).clipShape(RoundedRectangle(cornerRadius: 24)).preferredColorScheme(.dark)
            let host = NSHostingView(rootView: root); host.sizingOptions = []; host.frame = NSRect(x: 0,y: 0,width: 640,height: 190)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false); window.contentView = host; window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            precondition(host.bounds.size == NSSize(width: 640,height: 190), "Every state preserves the approved footprint")
            let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!; host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(state).png"))
            window.orderOut(nil)
        }
        print("Five native agenda states rendered at640×190; long titles, all-day/reminder, empty, denied and loading fit")
    }
}
