import AppKit
import Combine
import Foundation

// Only the settings store and battery source are doubled. The production manager,
// notification subscriptions and policy run unchanged in this native executable.
enum Defaults {
    class Keys {}
    final class Key<Value>: Keys {
        let defaultValue: Value
        init(_ name: String, default value: Value) { defaultValue = value }
    }
    struct Change { let newValue: Bool }
    static var value = true
    static let changes = PassthroughSubject<Change, Never>()
    static subscript(_ key: Key<Bool>) -> Bool {
        get { value }
        set { value = newValue; changes.send(Change(newValue: newValue)) }
    }
    static func publisher(_ key: Key<Bool>) -> AnyPublisher<Change, Never> {
        changes.eraseToAnyPublisher()
    }
}

final class BatteryStatusViewModel: ObservableObject {
    static let shared = BatteryStatusViewModel()
    @Published var isPluggedIn = true
    @Published var maxCapacity: Float = 100
}

@main struct PersonalEnergyTests {
    static var failures = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        if value() { print("PASS: \(message)") }
        else { failures += 1; print("FAIL: \(message)") }
    }
    static func pump() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03)) }

    static func main() {
        // A wrong battery/thermal/Low Power branch would leave decorative work
        // enabled or refresh progress twice as often in any of these scenarios.
        let normal = PersonalEnergyPolicy(PersonalEnergyInputs())
        check(normal.allowsDecorativeAnimation && normal.progressInterval == 0.5,
              "awake AC playback keeps smooth progress and decoration")
        for reason in ["battery", "low power", "thermal"] {
            var inputs = PersonalEnergyInputs()
            if reason == "battery" { inputs.onBattery = true }
            if reason == "low power" { inputs.lowPowerMode = true }
            if reason == "thermal" { inputs.thermalPressure = true }
            let policy = PersonalEnergyPolicy(inputs)
            check(policy.conservesEnergy && !policy.allowsDecorativeAnimation && policy.progressInterval == 1,
                  "\(reason) stops decorative loops and slows progress")
            inputs.adaptiveSavingEnabled = false
            check(PersonalEnergyPolicy(inputs).allowsDecorativeAnimation,
                  "explicit opt out restores decoration on \(reason)")
        }
        var inputs = PersonalEnergyInputs()
        inputs.adaptiveSavingEnabled = false
        inputs.reduceMotion = true
        check(!PersonalEnergyPolicy(inputs).allowsDecorativeAnimation,
              "Reduce Motion stays respected with adaptive saving disabled")
        check(PersonalEnergyPolicy(inputs).conservesEnergy,
              "Reduce Motion also disables decorative blur")

        let workspace = NotificationCenter()
        let distributed = NotificationCenter()
        let system = NotificationCenter()
        var systemState = PersonalSystemEnergyState(lowPowerMode: false, thermalPressure: false, reduceMotion: false)
        let manager = PersonalEnergyManager(systemCenter: system, workspaceCenter: workspace,
                                            sessionCenter: distributed, readSystemState: { systemState })
        var emissions = 0
        let subscription = manager.$policy.dropFirst().sink { _ in emissions += 1 }
        pump()
        check(manager.allowsDecorativeAnimation, "initial desktop state is awake")
        check(Defaults.Keys.adaptiveEnergySaving.defaultValue, "adaptive saving is enabled by default")

        BatteryStatusViewModel.shared.isPluggedIn = false
        pump()
        check(manager.conservesEnergy, "existing battery publisher activates savings")
        let changed = emissions
        BatteryStatusViewModel.shared.isPluggedIn = false
        pump()
        check(emissions == changed, "duplicate source values do not redraw the panel")
        BatteryStatusViewModel.shared.maxCapacity = 0
        pump()
        check(!manager.conservesEnergy, "missing battery does not make a desktop conserve")

        Defaults[.adaptiveEnergySaving] = false
        systemState.lowPowerMode = true
        system.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        pump()
        check(!manager.conservesEnergy, "settings opt out applies to system Low Power events")
        Defaults[.adaptiveEnergySaving] = true
        pump()
        check(manager.conservesEnergy, "settings opt in immediately reapplies current system state")
        systemState.lowPowerMode = false
        systemState.thermalPressure = true
        system.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        pump()
        check(manager.conservesEnergy, "thermal notifications refresh policy")
        systemState.thermalPressure = false
        systemState.reduceMotion = true
        workspace.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        pump()
        check(!manager.allowsDecorativeAnimation, "accessibility notifications stop decorative loops")
        systemState.reduceMotion = false
        workspace.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        pump()

        workspace.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        pump()
        check(!manager.screenIsAwake && !manager.allowsDecorativeAnimation, "sleep suspends UI work")
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        pump()
        check(!manager.screenIsAwake, "system wake alone cannot resume a sleeping display")
        distributed.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        workspace.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        pump()
        check(!manager.screenIsAwake, "display wake cannot resume a locked session")
        distributed.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        pump()
        check(manager.screenIsAwake && manager.allowsDecorativeAnimation, "unlock resumes eligible UI work")
        workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        pump()
        check(!manager.screenIsAwake, "display wake does not override an inactive user session")
        workspace.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        pump()
        check(manager.screenIsAwake, "returning to the session restores visible work")
        withExtendedLifetime(subscription) {}
        if failures > 0 { exit(1) }
        print("Personal energy checks passed")
    }
}
