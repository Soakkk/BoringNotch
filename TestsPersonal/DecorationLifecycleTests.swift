import AppKit
import SwiftUI
import ObjectiveC

private enum ScheduledTimers {
    static var timers: [Timer] = []
}

extension Timer {
    @objc class func personalScheduledTimer(withTimeInterval interval: TimeInterval,
                                            repeats: Bool,
                                            block: @escaping (Timer) -> Void) -> Timer {
        let timer = personalScheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
        ScheduledTimers.timers.append(timer)
        return timer
    }
}

@main
struct DecorationLifecycleTests {
    static var failures = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() { print("PASS: \(message)") }
        else { failures += 1; print("FAIL: \(message)") }
    }

    static func pump(_ interval: TimeInterval = 0.08) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: interval))
    }

    static func snapshot(_ host: NSView) -> Data {
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        let image = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: image)
        return image.representation(using: .png, properties: [:])!
    }

    static func capturedTimers(interval: TimeInterval, since index: Int) -> [Timer] {
        Array(ScheduledTimers.timers.dropFirst(index)).filter { abs($0.timeInterval - interval) < 0.001 }
    }

    static func main() {
        _ = NSApplication.shared
        let original = class_getClassMethod(Timer.self, #selector(Timer.scheduledTimer(withTimeInterval:repeats:block:)))!
        let replacement = class_getClassMethod(Timer.self, #selector(Timer.personalScheduledTimer(withTimeInterval:repeats:block:)))!
        method_exchangeImplementations(original, replacement)
        defer {
            method_exchangeImplementations(original, replacement)
            ScheduledTimers.timers.forEach { $0.invalidate() }
        }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 250, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: AnyView(EmptyView()))
        window.contentView = host
        window.orderFrontRegardless()
        pump()

        // Removing the view must invalidate the real timer, even if playback stays true.
        let start = ScheduledTimers.timers.count
        var spectrum: AudioSpectrum? = AudioSpectrum()
        window.contentView = spectrum
        spectrum!.setPlaying(true)
        pump(0.35)
        let playingTimers = capturedTimers(interval: 0.3, since: start)
        check(playingTimers.contains { $0.isValid }, "visible playing spectrum starts its timer")
        check(spectrum!.layer!.sublayers!.contains { !($0.animationKeys() ?? []).isEmpty },
              "visible playing spectrum animates bars")
        spectrum!.setPlaying(false)
        check(playingTimers.allSatisfy { !$0.isValid }, "pausing spectrum invalidates its timer")
        check(spectrum!.layer!.sublayers!.allSatisfy { ($0.animationKeys() ?? []).isEmpty },
              "pausing spectrum removes layer animations")
        spectrum!.setPlaying(true)
        spectrum!.setPlaying(true)
        check(capturedTimers(interval: 0.3, since: start).filter { $0.isValid }.count == 1,
              "repeated playback updates keep a single spectrum timer")
        spectrum!.setReduceMotion(true)
        check(capturedTimers(interval: 0.3, since: start).allSatisfy { !$0.isValid },
              "Reduce Motion stops spectrum timers")
        spectrum!.setReduceMotion(false)
        spectrum!.isHidden = true
        check(capturedTimers(interval: 0.3, since: start).allSatisfy { !$0.isValid },
              "hiding spectrum stops its timer")
        spectrum!.isHidden = false
        pump(0.35)
        let resumedTimers = capturedTimers(interval: 0.3, since: start)
        check(resumedTimers.filter { $0.isValid }.count == 1, "showing spectrum resumes one timer")
        spectrum!.removeFromSuperview()
        pump()
        check(resumedTimers.allSatisfy { !$0.isValid }, "removing spectrum invalidates its timer")
        check(spectrum!.layer!.sublayers!.allSatisfy { ($0.animationKeys() ?? []).isEmpty },
              "removing spectrum removes layer animations")
        spectrum = nil
        check(resumedTimers.allSatisfy { !$0.isValid }, "deallocating spectrum leaves no valid timer")

        let unattachedStart = ScheduledTimers.timers.count
        let unattachedSpectrum = AudioSpectrum()
        unattachedSpectrum.setPlaying(true)
        check(capturedTimers(interval: 0.3, since: unattachedStart).allSatisfy { !$0.isValid },
              "detached spectrum does not start background work")
        window.contentView = unattachedSpectrum
        pump()
        window.orderOut(nil)
        pump()
        check(capturedTimers(interval: 0.3, since: unattachedStart).allSatisfy { !$0.isValid },
              "ordering window out stops spectrum timer")
        window.orderFrontRegardless()
        pump()

        window.contentView = host
        host.rootView = AnyView(MinimalFaceFeatures())
        host.layoutSubtreeIfNeeded()
        pump()
        let openEyes = snapshot(host)
        let blinkDeadline = Date(timeIntervalSinceNow: 3.4)
        var observedBlink = false
        while Date() < blinkDeadline && !observedBlink {
            pump(0.02)
            observedBlink = snapshot(host) != openEyes
        }
        check(observedBlink, "visible face still blinks")
        pump(0.4)
        check(snapshot(host) == openEyes, "face reopens its eyes after blinking")
        host.rootView = AnyView(EmptyView())
        pump()
        host.rootView = AnyView(MinimalFaceFeatures(animationEnabled: false))
        host.layoutSubtreeIfNeeded()
        pump()
        let stillFace = snapshot(host)
        let stillDeadline = Date(timeIntervalSinceNow: 3.4)
        var stayedStill = true
        while Date() < stillDeadline {
            pump(0.02)
            if snapshot(host) != stillFace { stayedStill = false; break }
        }
        check(stayedStill, "energy saving keeps the face static beyond its blink interval")
        host.rootView = AnyView(EmptyView())
        pump()
        let faceStart = ScheduledTimers.timers.count
        for _ in 0..<3 {
            host.rootView = AnyView(MinimalFaceFeatures())
            host.layoutSubtreeIfNeeded()
            pump()
            host.rootView = AnyView(EmptyView())
            host.layoutSubtreeIfNeeded()
            pump()
        }
        check(capturedTimers(interval: 3, since: faceStart).allSatisfy { !$0.isValid },
              "repeated face mount/unmount leaves no repeating timer")

        let representedStart = ScheduledTimers.timers.count
        for _ in 0..<3 {
            host.rootView = AnyView(AudioSpectrumView(isPlaying: .constant(true)))
            pump(0.35)
            check(capturedTimers(interval: 0.3, since: representedStart).filter { $0.isValid }.count == 1,
                  "mounted spectrum representable owns one timer")
            host.rootView = AnyView(EmptyView())
            pump()
            check(capturedTimers(interval: 0.3, since: representedStart).allSatisfy { !$0.isValid },
                  "dismantling spectrum representable cancels all timers")
        }

        let longTitle = "A very long song title scrolling through the narrow music panel"
        host.rootView = AnyView(MarqueeText(.constant(longTitle), minDuration: 0, frameWidth: 80, isPlaying: true))
        pump(0.2)
        let movingTitle = snapshot(host)
        pump(0.4)
        check(snapshot(host) != movingTitle, "playing long title actually scrolls")

        host.rootView = AnyView(MarqueeText(.constant(longTitle), minDuration: 0, frameWidth: 80, isPlaying: false))
        pump(0.2)
        let stillTitle = snapshot(host)
        pump(0.4)
        check(snapshot(host) == stillTitle, "pausing playback keeps long title stationary")

        window.orderOut(nil)
        window.contentView = nil
        window.close()
        if failures > 0 { exit(1) }
        print("Decoration lifecycle checks passed")
    }
}
