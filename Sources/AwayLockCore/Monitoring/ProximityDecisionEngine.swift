import Foundation

public enum ProximityInput: Equatable {
    case found(rssi: Int)
    case missing
}

public struct ProximityDecision: Equatable {
    public let status: ProximityStatus
    public let currentRssi: Int?
    public let averageRssi: Double?
    public let countdownRemaining: TimeInterval?
    public let lockReason: LockReason?
}

public struct ProximityDecisionEngine: Equatable {
    public private(set) var rssiWindow: RSSIWindow
    public private(set) var missingSince: Date?
    public private(set) var weakSignalSince: Date?

    public init(windowSize: Int) {
        rssiWindow = RSSIWindow(size: windowSize)
    }

    public mutating func resetTransientState(windowSize: Int) {
        rssiWindow = RSSIWindow(size: windowSize)
        missingSince = nil
        weakSignalSince = nil
    }

    public mutating func evaluate(
        input: ProximityInput,
        now: Date,
        settings: ProximitySettingsSnapshot,
        isPaused: Bool,
        isInCooldown: Bool
    ) -> ProximityDecision {
        if !settings.isEnabled {
            resetTransientState(windowSize: settings.rssiAverageWindow)
            return ProximityDecision(
                status: .disabled,
                currentRssi: nil,
                averageRssi: nil,
                countdownRemaining: nil,
                lockReason: nil
            )
        }

        if isPaused {
            resetTransientState(windowSize: settings.rssiAverageWindow)
            return ProximityDecision(
                status: .paused,
                currentRssi: nil,
                averageRssi: nil,
                countdownRemaining: nil,
                lockReason: nil
            )
        }

        if isInCooldown {
            return ProximityDecision(
                status: .locked,
                currentRssi: nil,
                averageRssi: rssiWindow.average,
                countdownRemaining: nil,
                lockReason: nil
            )
        }

        rssiWindow.resize(settings.rssiAverageWindow)

        switch input {
        case .found(let rssi):
            missingSince = nil
            rssiWindow.append(rssi)

            guard let average = rssiWindow.average else {
                return ProximityDecision(
                    status: .nearby,
                    currentRssi: rssi,
                    averageRssi: nil,
                    countdownRemaining: nil,
                    lockReason: nil
                )
            }

            guard average < Double(settings.rssiThreshold) else {
                weakSignalSince = nil
                return ProximityDecision(
                    status: .nearby,
                    currentRssi: rssi,
                    averageRssi: average,
                    countdownRemaining: nil,
                    lockReason: nil
                )
            }

            if weakSignalSince == nil {
                weakSignalSince = now
            }

            let duration = now.timeIntervalSince(weakSignalSince ?? now)
            if duration >= settings.weakSignalTimeout {
                return ProximityDecision(
                    status: .locked,
                    currentRssi: rssi,
                    averageRssi: average,
                    countdownRemaining: 0,
                    lockReason: .weakSignal
                )
            }

            return ProximityDecision(
                status: .lockingPending,
                currentRssi: rssi,
                averageRssi: average,
                countdownRemaining: max(0, settings.weakSignalTimeout - duration),
                lockReason: nil
            )

        case .missing:
            weakSignalSince = nil

            if missingSince == nil {
                missingSince = now
            }

            let duration = now.timeIntervalSince(missingSince ?? now)
            if duration >= settings.missingDeviceTimeout {
                return ProximityDecision(
                    status: .locked,
                    currentRssi: nil,
                    averageRssi: rssiWindow.average,
                    countdownRemaining: 0,
                    lockReason: .deviceNotFound
                )
            }

            return ProximityDecision(
                status: .lockingPending,
                currentRssi: nil,
                averageRssi: rssiWindow.average,
                countdownRemaining: max(0, settings.missingDeviceTimeout - duration),
                lockReason: nil
            )
        }
    }
}
