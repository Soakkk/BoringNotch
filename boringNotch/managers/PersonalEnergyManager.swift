import AppKit
import Combine
import Defaults

extension Defaults.Keys {
    static let adaptiveEnergySaving = Defaults.Key<Bool>("adaptiveEnergySaving", default: true)
}

struct PersonalEnergyInputs {
    var adaptiveSavingEnabled = true
    var onBattery = false
    var lowPowerMode = false
    var thermalPressure = false
    var reduceMotion = false
    var systemIsAwake = true
    var displayIsAwake = true
    var sessionIsActive = true
    var screenIsLocked = false
}

struct PersonalEnergyPolicy: Equatable {
    let conservesEnergy: Bool
    let screenIsAwake: Bool
    let allowsDecorativeAnimation: Bool
    let progressInterval: TimeInterval

    init(_ inputs: PersonalEnergyInputs) {
        conservesEnergy = inputs.reduceMotion || (inputs.adaptiveSavingEnabled &&
            (inputs.onBattery || inputs.lowPowerMode || inputs.thermalPressure))
        screenIsAwake = inputs.systemIsAwake && inputs.displayIsAwake &&
            inputs.sessionIsActive && !inputs.screenIsLocked
        allowsDecorativeAnimation = screenIsAwake && !conservesEnergy
        progressInterval = conservesEnergy ? 1 : 0.5
    }
}

struct PersonalSystemEnergyState {
    var lowPowerMode: Bool
    var thermalPressure: Bool
    var reduceMotion: Bool

    static var current: Self {
        Self(lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
             thermalPressure: ProcessInfo.processInfo.thermalState != .nominal,
             reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}

final class PersonalEnergyManager: ObservableObject {
    static let shared = PersonalEnergyManager()
    @Published private(set) var policy = PersonalEnergyPolicy(PersonalEnergyInputs())

    var conservesEnergy: Bool { policy.conservesEnergy }
    var screenIsAwake: Bool { policy.screenIsAwake }
    var allowsDecorativeAnimation: Bool { policy.allowsDecorativeAnimation }
    var progressInterval: TimeInterval { policy.progressInterval }

    private var inputs = PersonalEnergyInputs()
    private var subscriptions = Set<AnyCancellable>()
    private let readSystemState: () -> PersonalSystemEnergyState

    init(systemCenter: NotificationCenter = .default,
         workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
         sessionCenter: NotificationCenter = DistributedNotificationCenter.default(),
         readSystemState: @escaping () -> PersonalSystemEnergyState = { .current }) {
        self.readSystemState = readSystemState
        let battery = BatteryStatusViewModel.shared
        inputs.adaptiveSavingEnabled = Defaults[.adaptiveEnergySaving]
        inputs.onBattery = battery.maxCapacity > 0 && !battery.isPluggedIn
        refreshSystemState()

        Defaults.publisher(.adaptiveEnergySaving)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.inputs.adaptiveSavingEnabled = change.newValue
                self?.refreshSystemState()
            }
            .store(in: &subscriptions)

        // Reuse the existing IOKit battery monitor. Capacity distinguishes a
        // portable on battery from a desktop with no power-source information.
        battery.$isPluggedIn.combineLatest(battery.$maxCapacity)
            .map { pluggedIn, capacity in capacity > 0 && !pluggedIn }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] onBattery in
                self?.inputs.onBattery = onBattery
                self?.publishPolicy()
            }
            .store(in: &subscriptions)

        observe(systemCenter, .NSProcessInfoPowerStateDidChange)
        observe(systemCenter, ProcessInfo.thermalStateDidChangeNotification)
        observe(workspaceCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
        observe(workspaceCenter, NSWorkspace.willSleepNotification) { $0.systemIsAwake = false }
        observe(workspaceCenter, NSWorkspace.didWakeNotification) { $0.systemIsAwake = true }
        observe(workspaceCenter, NSWorkspace.screensDidSleepNotification) { $0.displayIsAwake = false }
        observe(workspaceCenter, NSWorkspace.screensDidWakeNotification) { $0.displayIsAwake = true }
        observe(workspaceCenter, NSWorkspace.sessionDidResignActiveNotification) { $0.sessionIsActive = false }
        observe(workspaceCenter, NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionIsActive = true }
        observe(sessionCenter, Notification.Name("com.apple.screenIsLocked")) { $0.screenIsLocked = true }
        observe(sessionCenter, Notification.Name("com.apple.screenIsUnlocked")) { $0.screenIsLocked = false }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         update: @escaping (inout PersonalEnergyInputs) -> Void = { _ in }) {
        center.publisher(for: name)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                update(&self.inputs)
                self.refreshSystemState()
            }
            .store(in: &subscriptions)
    }

    private func refreshSystemState() {
        let state = readSystemState()
        inputs.lowPowerMode = state.lowPowerMode
        inputs.thermalPressure = state.thermalPressure
        inputs.reduceMotion = state.reduceMotion
        publishPolicy()
    }

    private func publishPolicy() {
        let next = PersonalEnergyPolicy(inputs)
        guard next != policy else { return }
        policy = next
    }
}
