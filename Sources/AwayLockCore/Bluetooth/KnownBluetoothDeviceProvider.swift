import Foundation
import IOBluetooth

public struct KnownBluetoothDevice: Hashable {
    public let name: String
    public let address: String?

    public init(name: String, address: String?) {
        self.name = name
        self.address = address
    }
}

public enum KnownBluetoothDeviceProvider {
    public static func pairedDevices() -> [KnownBluetoothDevice] {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []

        return paired.compactMap { device in
            let name = device.name ?? device.nameOrAddress
            guard let name, !name.isEmpty else {
                return nil
            }

            return KnownBluetoothDevice(
                name: name,
                address: device.addressString
            )
        }
    }

    public static func isKnownDevice(_ device: BluetoothDevice, knownDevices: [KnownBluetoothDevice]) -> Bool {
        let normalizedDeviceName = normalize(device.name)

        return knownDevices.contains { knownDevice in
            let knownName = normalize(knownDevice.name)
            return normalizedDeviceName == knownName ||
                normalizedDeviceName.contains(knownName) ||
                knownName.contains(normalizedDeviceName)
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
