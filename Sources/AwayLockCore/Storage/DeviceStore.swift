import Foundation

@MainActor
public final class DeviceStore: ObservableObject {
    @Published public private(set) var selectedDevice: SelectedDevice? {
        didSet { saveSelectedDevice() }
    }

    private let defaults: UserDefaults
    private let key = "device.selected"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedDevice = Self.loadSelectedDevice(defaults: defaults, key: key)
    }

    public func select(_ device: BluetoothDevice) {
        selectedDevice = SelectedDevice(
            name: device.name,
            identifier: device.identifier,
            lastKnownRssi: device.rssi,
            selectedAt: Date()
        )
    }

    public func clearSelection() {
        selectedDevice = nil
    }

    public func updateLastKnownRssi(_ rssi: Int) {
        guard var selectedDevice else {
            return
        }

        selectedDevice.lastKnownRssi = rssi
        self.selectedDevice = selectedDevice
    }

    private func saveSelectedDevice() {
        guard let selectedDevice else {
            defaults.removeObject(forKey: key)
            return
        }

        if let data = try? JSONEncoder().encode(selectedDevice) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadSelectedDevice(defaults: UserDefaults, key: String) -> SelectedDevice? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(SelectedDevice.self, from: data)
    }
}
