import CoreBluetooth
import Foundation

@MainActor
public final class BluetoothScanner: NSObject, ObservableObject {
    @Published public private(set) var discoveredDevices: [UUID: BluetoothDevice] = [:]
    @Published public private(set) var availability: BluetoothAvailability = .unknown
    @Published public private(set) var isScanning = false

    private var centralManager: CBCentralManager?
    private let logger: EventLogger

    public init(logger: EventLogger) {
        self.logger = logger
        super.init()
    }

    public var devices: [BluetoothDevice] {
        Self.sortDevices(discoveredDevices.values)
    }

    public static func sortDevices<S: Sequence>(_ devices: S) -> [BluetoothDevice] where S.Element == BluetoothDevice {
        devices.sorted { lhs, rhs in
            lhs.identifier.uuidString.localizedStandardCompare(rhs.identifier.uuidString) == .orderedAscending
        }
    }

    public func startScanning() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .main)
            return
        }

        guard availability == .poweredOn, let centralManager else {
            return
        }

        guard !isScanning else {
            return
        }

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
        logger.add("Bluetooth scan started")
    }

    public func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        logger.add("Bluetooth scan stopped")
    }

    public func device(identifier: UUID) -> BluetoothDevice? {
        discoveredDevices[identifier]
    }

    public func removeStaleDevices(olderThan interval: TimeInterval, now: Date = Date()) {
        discoveredDevices = discoveredDevices.filter { _, device in
            now.timeIntervalSince(device.lastSeen) <= interval
        }
    }

    private func handleStateChange(_ state: CBManagerState) {
        availability = BluetoothAvailability(state: state)

        switch availability {
        case .poweredOn:
            logger.add("Bluetooth is powered on")
            startScanning()
        case .poweredOff:
            isScanning = false
            logger.add("Bluetooth is powered off")
        case .unauthorized:
            isScanning = false
            logger.add("Bluetooth permission is not granted")
        case .unsupported:
            isScanning = false
            logger.add("Bluetooth is not supported on this Mac")
        case .resetting:
            isScanning = false
            logger.add("Bluetooth is resetting")
        case .unknown:
            isScanning = false
            logger.add("Bluetooth state is unknown")
        }
    }

    private func handleDiscovery(identifier: UUID, name: String?, rssi: Int) {
        let displayName = (name?.isEmpty == false ? name : nil) ?? "Unnamed BLE Device"
        let device = BluetoothDevice(
            name: displayName,
            identifier: identifier,
            rssi: rssi,
            lastSeen: Date()
        )
        discoveredDevices[identifier] = device
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor [weak self] in
            self?.handleStateChange(state)
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisementName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advertisementName
        let identifier = peripheral.identifier
        let rssi = RSSI.intValue

        Task { @MainActor [weak self] in
            self?.handleDiscovery(identifier: identifier, name: name, rssi: rssi)
        }
    }
}
