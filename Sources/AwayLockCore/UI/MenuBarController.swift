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

    private let navigation = PopoverNavigation()
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
        button.action = #selector(handleStatusButtonClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: AwayMenuPopoverView(
                navigation: navigation,
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
        switch monitor.status {
        case .nearby:
            symbolName = "lock.shield"
        case .weakSignal, .lockingPending:
            symbolName = "exclamationmark.triangle"
        case .notFound, .bluetoothUnavailable:
            symbolName = "lock.slash"
        case .locked:
            symbolName = "lock.fill"
        case .paused:
            symbolName = "pause.circle"
        case .disabled:
            symbolName = "lock.open"
        }

        if let image = whiteStatusImage(named: symbolName) {
            button.image = image
        } else {
            button.title = "AL"
            button.contentTintColor = .white
        }
    }

    private func whiteStatusImage(named symbolName: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [.white])
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "AwayLock")?
            .withSymbolConfiguration(configuration) else {
            return nil
        }

        image.isTemplate = false
        return image
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

    @objc private func handleStatusButtonClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        togglePopover()
    }

    @objc private func openDashboardFromMenu() {
        showPopover(section: .overview)
    }

    @objc private func openDeviceSelectionFromMenu() {
        showPopover(section: .devices)
    }

    @objc private func openSettingsFromMenu() {
        showPopover(section: .settings)
    }

    @objc private func lockNowFromMenu() {
        lockNow()
    }

    @objc private func openAboutFromMenu() {
        showPopover(section: .about)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(section: PopoverSection) {
        navigation.section = section

        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.contentViewController?.view.window?.makeKey()
            return
        }

        showPopover(relativeTo: button)
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(menuItem("Dashboard", action: #selector(openDashboardFromMenu), keyEquivalent: ""))
        menu.addItem(menuItem("Select Device", action: #selector(openDeviceSelectionFromMenu), keyEquivalent: ""))
        menu.addItem(menuItem("Settings", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem("Lock Now", action: #selector(lockNowFromMenu), keyEquivalent: "l"))
        addSelectedDeviceStats(to: menu)
        menu.addItem(.separator())
        menu.addItem(menuItem("About AwayLock", action: #selector(openAboutFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit", action: #selector(quitFromMenu), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func menuItem(_ title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func addSelectedDeviceStats(to menu: NSMenu) {
        guard let selectedDevice = deviceStore.selectedDevice else {
            return
        }

        menu.addItem(.separator())
        menu.addItem(disabledMenuItem("Device: \(selectedDevice.name)"))
        menu.addItem(disabledMenuItem("Status: \(statusDescription())"))
        menu.addItem(disabledMenuItem("RSSI: \(currentRssiDescription())"))
        menu.addItem(disabledMenuItem("Average: \(averageRssiDescription())"))

        if let visibleDevice = scanner.devices.first(where: { $0.identifier == selectedDevice.identifier }) {
            menu.addItem(disabledMenuItem("Last seen: \(relativeDateDescription(visibleDevice.lastSeen))"))
        }
    }

    private func disabledMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func averageRssiDescription() -> String {
        guard let averageRssi = monitor.averageRssi else {
            return "Unknown"
        }
        return "\(Int(averageRssi.rounded())) dBm"
    }

    private func relativeDateDescription(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date).rounded()))
        if seconds < 2 {
            return "now"
        }
        if seconds < 60 {
            return "\(seconds)s ago"
        }
        return "\(seconds / 60)m ago"
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
