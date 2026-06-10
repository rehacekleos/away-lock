import Foundation
import Testing
@testable import AwayLockCore

@Test func rssiWindowMaintainsMovingAverage() {
    var window = RSSIWindow(size: 3)

    window.append(-60)
    window.append(-70)
    window.append(-80)
    window.append(-90)

    #expect(window.values == [-70, -80, -90])
    #expect(window.average == -80)
}

@Test func missingDeviceRequiresTimeoutBeforeLocking() {
    var engine = ProximityDecisionEngine(windowSize: 8)
    let settings = ProximitySettingsSnapshot(missingDeviceTimeout: 20)
    let start = Date(timeIntervalSince1970: 100)

    let initial = engine.evaluate(
        input: .missing,
        now: start,
        settings: settings,
        isPaused: false,
        isInCooldown: false
    )
    #expect(initial.status == ProximityStatus.lockingPending)
    #expect(initial.lockReason == nil)

    let tooSoon = engine.evaluate(
        input: .missing,
        now: start.addingTimeInterval(19),
        settings: settings,
        isPaused: false,
        isInCooldown: false
    )
    #expect(tooSoon.status == ProximityStatus.lockingPending)
    #expect(tooSoon.lockReason == nil)

    let timedOut = engine.evaluate(
        input: .missing,
        now: start.addingTimeInterval(20),
        settings: settings,
        isPaused: false,
        isInCooldown: false
    )
    #expect(timedOut.status == ProximityStatus.locked)
    #expect(timedOut.lockReason == LockReason.deviceNotFound)
}

@Test func weakSignalUsesAverageAndTimeout() {
    var engine = ProximityDecisionEngine(windowSize: 3)
    let settings = ProximitySettingsSnapshot(
        weakSignalTimeout: 20,
        rssiThreshold: -75,
        rssiAverageWindow: 3
    )
    let start = Date(timeIntervalSince1970: 200)

    _ = engine.evaluate(input: .found(rssi: -70), now: start, settings: settings, isPaused: false, isInCooldown: false)
    _ = engine.evaluate(input: .found(rssi: -78), now: start.addingTimeInterval(1), settings: settings, isPaused: false, isInCooldown: false)
    let stillNearby = engine.evaluate(input: .found(rssi: -76), now: start.addingTimeInterval(2), settings: settings, isPaused: false, isInCooldown: false)
    #expect(stillNearby.status == ProximityStatus.nearby)
    #expect(stillNearby.lockReason == nil)

    let weakStarted = engine.evaluate(input: .found(rssi: -90), now: start.addingTimeInterval(3), settings: settings, isPaused: false, isInCooldown: false)
    #expect(weakStarted.status == ProximityStatus.lockingPending)
    #expect(weakStarted.lockReason == nil)

    let timedOut = engine.evaluate(input: .found(rssi: -88), now: start.addingTimeInterval(23), settings: settings, isPaused: false, isInCooldown: false)
    #expect(timedOut.status == ProximityStatus.locked)
    #expect(timedOut.lockReason == LockReason.weakSignal)
}

@Test func pausedAndDisabledStatesNeverLock() {
    var engine = ProximityDecisionEngine(windowSize: 8)
    let enabledSettings = ProximitySettingsSnapshot(missingDeviceTimeout: 1)
    let disabledSettings = ProximitySettingsSnapshot(isEnabled: false, missingDeviceTimeout: 1)
    let start = Date(timeIntervalSince1970: 300)

    let paused = engine.evaluate(
        input: .missing,
        now: start.addingTimeInterval(5),
        settings: enabledSettings,
        isPaused: true,
        isInCooldown: false
    )
    #expect(paused.status == ProximityStatus.paused)
    #expect(paused.lockReason == nil)

    let disabled = engine.evaluate(
        input: .missing,
        now: start.addingTimeInterval(10),
        settings: disabledSettings,
        isPaused: false,
        isInCooldown: false
    )
    #expect(disabled.status == ProximityStatus.disabled)
    #expect(disabled.lockReason == nil)
}

@MainActor
@Test func knownDeviceMatchingDoesNotTrustSubstringNames() {
    let device = BluetoothDevice(
        name: "Leos iPhone Clone",
        identifier: UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000000")!,
        rssi: -45,
        lastSeen: Date(timeIntervalSince1970: 450)
    )
    let knownDevices = [
        KnownBluetoothDevice(name: "Leos iPhone", address: "AA-BB-CC-DD-EE-FF")
    ]

    #expect(KnownBluetoothDeviceProvider.isKnownDevice(device, knownDevices: knownDevices) == false)
}

@MainActor
@Test func knownDeviceMatchingAllowsExactNormalizedNamesOnly() {
    let device = BluetoothDevice(
        name: "  LEOS IPHONE  ",
        identifier: UUID(uuidString: "EEEEEEEE-0000-0000-0000-000000000000")!,
        rssi: -45,
        lastSeen: Date(timeIntervalSince1970: 460)
    )
    let knownDevices = [
        KnownBluetoothDevice(name: "Leos iPhone", address: "AA-BB-CC-DD-EE-FF")
    ]

    #expect(KnownBluetoothDeviceProvider.isKnownDevice(device, knownDevices: knownDevices) == true)
}

@MainActor
@Test func bluetoothDevicesSortByIdentifierForStablePickerOrder() {
    let now = Date(timeIntervalSince1970: 400)
    let devices = [
        BluetoothDevice(
            name: "Newest Strongest",
            identifier: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000000")!,
            rssi: -40,
            lastSeen: now.addingTimeInterval(20)
        ),
        BluetoothDevice(
            name: "Oldest Weakest",
            identifier: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000000")!,
            rssi: -90,
            lastSeen: now
        ),
        BluetoothDevice(
            name: "Middle",
            identifier: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000000")!,
            rssi: -70,
            lastSeen: now.addingTimeInterval(10)
        )
    ]

    let sorted = BluetoothScanner.sortDevices(devices)

    #expect(sorted.map(\.identifier.uuidString) == [
        "AAAAAAAA-0000-0000-0000-000000000000",
        "BBBBBBBB-0000-0000-0000-000000000000",
        "CCCCCCCC-0000-0000-0000-000000000000"
    ])
}
