import CoreBluetooth
import Foundation

public struct BluetoothDevice: Identifiable, Codable, Hashable {
    public var id: UUID { identifier }
    public var name: String
    public var identifier: UUID
    public var rssi: Int?
    public var lastSeen: Date

    public init(name: String, identifier: UUID, rssi: Int?, lastSeen: Date) {
        self.name = name
        self.identifier = identifier
        self.rssi = rssi
        self.lastSeen = lastSeen
    }
}

public struct SelectedDevice: Codable, Hashable {
    public var name: String
    public var identifier: UUID
    public var lastKnownRssi: Int?
    public var selectedAt: Date

    public init(name: String, identifier: UUID, lastKnownRssi: Int?, selectedAt: Date) {
        self.name = name
        self.identifier = identifier
        self.lastKnownRssi = lastKnownRssi
        self.selectedAt = selectedAt
    }
}

public enum BluetoothAvailability: String, Codable, Equatable {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn

    init(state: CBManagerState) {
        switch state {
        case .unknown:
            self = .unknown
        case .resetting:
            self = .resetting
        case .unsupported:
            self = .unsupported
        case .unauthorized:
            self = .unauthorized
        case .poweredOff:
            self = .poweredOff
        case .poweredOn:
            self = .poweredOn
        @unknown default:
            self = .unknown
        }
    }

    public var displayName: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .resetting:
            return "Resetting"
        case .unsupported:
            return "Unsupported"
        case .unauthorized:
            return "Permission needed"
        case .poweredOff:
            return "Bluetooth off"
        case .poweredOn:
            return "Powered on"
        }
    }
}

public enum ProximityStatus: String, Codable, CaseIterable, Equatable {
    case nearby
    case weakSignal
    case notFound
    case lockingPending
    case locked
    case paused
    case disabled
    case bluetoothUnavailable

    public var displayName: String {
        switch self {
        case .nearby:
            return "Nearby"
        case .weakSignal:
            return "Weak signal"
        case .notFound:
            return "Not found"
        case .lockingPending:
            return "Locking pending"
        case .locked:
            return "Locked"
        case .paused:
            return "Paused"
        case .disabled:
            return "Disabled"
        case .bluetoothUnavailable:
            return "Bluetooth unavailable"
        }
    }
}

public enum LockReason: String, Codable, Equatable {
    case deviceNotFound
    case weakSignal
    case manual

    public var displayName: String {
        switch self {
        case .deviceNotFound:
            return "device not found timeout"
        case .weakSignal:
            return "weak signal timeout"
        case .manual:
            return "manual lock"
        }
    }

    public var notificationDescription: String {
        switch self {
        case .deviceNotFound:
            return "the selected Bluetooth device was not found"
        case .weakSignal:
            return "the selected Bluetooth device had weak signal"
        case .manual:
            return "Lock Now was selected"
        }
    }
}
