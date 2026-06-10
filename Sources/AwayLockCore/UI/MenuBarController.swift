import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let settings: SettingsStore
    private let deviceStore: DeviceStore
    private let scanner: BluetoothScanner
    private let monitor: ProximityMonitor
    private let lockService: LockService
    private let logger: EventLogger

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let onboardingWindow = OnboardingWindowController()
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SettingsStore,
        deviceStore: DeviceStore,
        scanner: BluetoothScanner,
        monitor: ProximityMonitor,
        lockService: LockService,
        logger: EventLogger
    ) {
        self.settings = settings
        self.deviceStore = deviceStore
        self.scanner = scanner
        self.monitor = monitor
        self.lockService = lockService
        self.logger = logger
        super.init()

        bindUpdates()
        configurePopover()
        configureStatusButton()
        updateStatusItem()
    }

    func showOnboarding() {
        onboardingWindow.show()
    }

    private func bindUpdates() {
        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateStatusItem() }
            }
            .store(in: &cancellables)

        deviceStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateStatusItem() }
            }
            .store(in: &cancellables)

        monitor.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateStatusItem() }
            }
            .store(in: &cancellables)

        scanner.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateStatusItem() }
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        updateIcon()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 860, height: 640)
        popover.contentViewController = NSHostingController(
            rootView: AwayMenuPopoverView(
                settings: settings,
                deviceStore: deviceStore,
                scanner: scanner,
                monitor: monitor,
                logger: logger,
                lockNow: { [weak self] in
                    self?.lockNow()
                },
                pause: { [weak self] interval, label in
                    self?.pause(for: interval, label: label)
                },
                pauseUntilResumed: { [weak self] in
                    self?.pauseUntilResumed()
                },
                resume: { [weak self] in
                    self?.resumeMonitoring()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        )
    }

    private func updateIcon() {
        guard let button = statusItem.button else {
            return
        }

        let symbolName: String
        let tintColor: NSColor?

        switch monitor.status {
        case .nearby:
            symbolName = "lock.shield"
            tintColor = .controlAccentColor
        case .weakSignal, .lockingPending:
            symbolName = "exclamationmark.triangle"
            tintColor = .systemOrange
        case .notFound, .bluetoothUnavailable:
            symbolName = "lock.slash"
            tintColor = .systemRed
        case .locked:
            symbolName = "lock.fill"
            tintColor = .systemRed
        case .paused:
            symbolName = "pause.circle"
            tintColor = .systemBlue
        case .disabled:
            symbolName = "lock.open"
            tintColor = .disabledControlTextColor
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "AwayLock") {
            image.isTemplate = true
            button.image = image
            button.contentTintColor = tintColor
        } else {
            button.title = "AL"
        }
    }

    private func statusDescription() -> String {
        if let pauseDescription = settings.pauseDescription() {
            return pauseDescription
        }

        if let countdownRemaining = monitor.countdownRemaining {
            return "\(monitor.status.displayName) (\(Int(countdownRemaining.rounded(.up)))s)"
        }

        return monitor.status.displayName
    }

    private func currentRssiDescription() -> String {
        if let currentRssi = monitor.currentRssi {
            return "\(currentRssi) dBm"
        }

        if let selectedRssi = deviceStore.selectedDevice?.lastKnownRssi {
            return "\(selectedRssi) dBm last known"
        }

        return "Unknown"
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func toggleEnabled() {
        settings.isEnabled.toggle()
        logger.add("AwayLock \(settings.isEnabled ? "enabled" : "disabled")")
        monitor.evaluate()
    }

    private func lockNow() {
        lockService.lockNow(settings: settings.snapshot())
        monitor.evaluate()
    }

    private func pauseUntilResumed() {
        settings.pauseUntilResumed()
        logger.add("AwayLock is paused until resumed")
        monitor.evaluate()
    }

    private func resumeMonitoring() {
        settings.resume()
        logger.add("Proximity Lock resumed")
        monitor.evaluate()
    }

    private func pause(for interval: TimeInterval, label: String) {
        settings.pause(for: interval)
        logger.add("AwayLock is paused for \(label)")
        monitor.evaluate()
    }
}
