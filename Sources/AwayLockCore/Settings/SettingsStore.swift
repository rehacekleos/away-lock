import Foundation

public enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

public struct ProximitySettingsSnapshot: Equatable {
    public var isEnabled: Bool
    public var launchAtLogin: Bool
    public var scanInterval: TimeInterval
    public var missingDeviceTimeout: TimeInterval
    public var weakSignalTimeout: TimeInterval
    public var rssiThreshold: Int
    public var rssiAverageWindow: Int
    public var cooldownAfterLock: TimeInterval
    public var showNotifications: Bool

    public init(
        isEnabled: Bool = true,
        launchAtLogin: Bool = false,
        scanInterval: TimeInterval = 2,
        missingDeviceTimeout: TimeInterval = 20,
        weakSignalTimeout: TimeInterval = 20,
        rssiThreshold: Int = -75,
        rssiAverageWindow: Int = 8,
        cooldownAfterLock: TimeInterval = 60,
        showNotifications: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.launchAtLogin = launchAtLogin
        self.scanInterval = max(1, scanInterval)
        self.missingDeviceTimeout = max(1, missingDeviceTimeout)
        self.weakSignalTimeout = max(1, weakSignalTimeout)
        self.rssiThreshold = rssiThreshold
        self.rssiAverageWindow = max(1, rssiAverageWindow)
        self.cooldownAfterLock = max(1, cooldownAfterLock)
        self.showNotifications = showNotifications
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published public var scanInterval: TimeInterval {
        didSet { defaults.set(scanInterval, forKey: Key.scanInterval) }
    }

    @Published public var missingDeviceTimeout: TimeInterval {
        didSet { defaults.set(missingDeviceTimeout, forKey: Key.missingDeviceTimeout) }
    }

    @Published public var weakSignalTimeout: TimeInterval {
        didSet { defaults.set(weakSignalTimeout, forKey: Key.weakSignalTimeout) }
    }

    @Published public var rssiThreshold: Int {
        didSet { defaults.set(rssiThreshold, forKey: Key.rssiThreshold) }
    }

    @Published public var rssiAverageWindow: Int {
        didSet { defaults.set(rssiAverageWindow, forKey: Key.rssiAverageWindow) }
    }

    @Published public var cooldownAfterLock: TimeInterval {
        didSet { defaults.set(cooldownAfterLock, forKey: Key.cooldownAfterLock) }
    }

    @Published public var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: Key.showNotifications) }
    }

    @Published public var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    @Published public private(set) var pauseUntil: Date? {
        didSet { defaults.set(pauseUntil, forKey: Key.pauseUntil) }
    }

    @Published public private(set) var pauseIndefinitely: Bool {
        didSet { defaults.set(pauseIndefinitely, forKey: Key.pauseIndefinitely) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.isEnabled) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
        scanInterval = defaults.object(forKey: Key.scanInterval) as? TimeInterval ?? 2
        missingDeviceTimeout = defaults.object(forKey: Key.missingDeviceTimeout) as? TimeInterval ?? 20
        weakSignalTimeout = defaults.object(forKey: Key.weakSignalTimeout) as? TimeInterval ?? 20
        rssiThreshold = defaults.object(forKey: Key.rssiThreshold) as? Int ?? -75
        rssiAverageWindow = defaults.object(forKey: Key.rssiAverageWindow) as? Int ?? 8
        cooldownAfterLock = defaults.object(forKey: Key.cooldownAfterLock) as? TimeInterval ?? 60
        showNotifications = defaults.object(forKey: Key.showNotifications) as? Bool ?? true
        appearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        pauseUntil = defaults.object(forKey: Key.pauseUntil) as? Date
        pauseIndefinitely = defaults.object(forKey: Key.pauseIndefinitely) as? Bool ?? false
    }

    public var isFirstLaunch: Bool {
        !(defaults.object(forKey: Key.hasSeenOnboarding) as? Bool ?? false)
    }

    public func markOnboardingSeen() {
        defaults.set(true, forKey: Key.hasSeenOnboarding)
    }

    public func snapshot() -> ProximitySettingsSnapshot {
        ProximitySettingsSnapshot(
            isEnabled: isEnabled,
            launchAtLogin: launchAtLogin,
            scanInterval: scanInterval,
            missingDeviceTimeout: missingDeviceTimeout,
            weakSignalTimeout: weakSignalTimeout,
            rssiThreshold: rssiThreshold,
            rssiAverageWindow: rssiAverageWindow,
            cooldownAfterLock: cooldownAfterLock,
            showNotifications: showNotifications
        )
    }

    public func isPaused(now: Date = Date()) -> Bool {
        if pauseIndefinitely {
            return true
        }

        guard let pauseUntil else {
            return false
        }

        return pauseUntil > now
    }

    public func pause(for interval: TimeInterval) {
        pauseIndefinitely = false
        pauseUntil = Date().addingTimeInterval(interval)
    }

    public func pauseUntilResumed() {
        pauseUntil = nil
        pauseIndefinitely = true
    }

    public func resume() {
        pauseUntil = nil
        pauseIndefinitely = false
    }

    public func expirePauseIfNeeded(now: Date = Date()) {
        if let pauseUntil, pauseUntil <= now {
            self.pauseUntil = nil
        }
    }

    public func pauseDescription(now: Date = Date()) -> String? {
        if pauseIndefinitely {
            return "Paused until resumed"
        }

        guard let pauseUntil, pauseUntil > now else {
            return nil
        }

        let remaining = Int(pauseUntil.timeIntervalSince(now).rounded(.up))
        return "Paused for \(remaining)s"
    }

    private enum Key {
        static let isEnabled = "settings.isEnabled"
        static let launchAtLogin = "settings.launchAtLogin"
        static let scanInterval = "settings.scanInterval"
        static let missingDeviceTimeout = "settings.missingDeviceTimeout"
        static let weakSignalTimeout = "settings.weakSignalTimeout"
        static let rssiThreshold = "settings.rssiThreshold"
        static let rssiAverageWindow = "settings.rssiAverageWindow"
        static let cooldownAfterLock = "settings.cooldownAfterLock"
        static let showNotifications = "settings.showNotifications"
        static let appearance = "settings.appearance"
        static let pauseUntil = "settings.pauseUntil"
        static let pauseIndefinitely = "settings.pauseIndefinitely"
        static let hasSeenOnboarding = "settings.hasSeenOnboarding"
    }
}
