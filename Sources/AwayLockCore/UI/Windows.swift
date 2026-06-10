import AppKit
import SwiftUI

@MainActor
final class DeviceSelectionWindowController {
    private var window: NSWindow?

    func show(scanner: BluetoothScanner, deviceStore: DeviceStore, logger: EventLogger) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = DeviceSelectionView(scanner: scanner, deviceStore: deviceStore) { [weak self] device in
            deviceStore.select(device)
            logger.add("Selected device: \(device.name), RSSI \(device.rssi.map(String.init) ?? "unknown")")
            self?.window?.close()
        }

        window = makeWindow(
            title: "Select Bluetooth Device",
            size: NSSize(width: 740, height: 540),
            rootView: view
        )
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(settings: SettingsStore) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        window = makeWindow(
            title: "AwayLock Settings",
            size: NSSize(width: 660, height: 760),
            rootView: SettingsView(settings: settings)
        )
    }
}

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        window = makeWindow(
            title: "Set Up AwayLock",
            size: NSSize(width: 620, height: 560),
            rootView: OnboardingView()
        )
    }
}

@MainActor
private func makeWindow<Content: View>(title: String, size: NSSize, rootView: Content) -> NSWindow {
    let hostingController = NSHostingController(rootView: rootView)
    let window = NSWindow(contentViewController: hostingController)
    window.title = title
    window.setContentSize(size)
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.isReleasedWhenClosed = false
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    return window
}
