import AppKit
import SwiftUI

@MainActor
struct AwayMenuPopoverView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var deviceStore: DeviceStore
    @ObservedObject var scanner: BluetoothScanner
    @ObservedObject var monitor: ProximityMonitor
    @ObservedObject var logger: EventLogger

    let lockNow: () -> Void
    let pause: (TimeInterval, String) -> Void
    let pauseUntilResumed: () -> Void
    let resume: () -> Void
    let quit: () -> Void

    @State private var section: PopoverSection = .overview

    var body: some View {
        HStack(spacing: 0) {
            PopoverSidebar(section: $section, status: monitor.status)

            Divider()

            ZStack {
                switch section {
                case .overview:
                    PopoverOverviewView(
                        settings: settings,
                        deviceStore: deviceStore,
                        monitor: monitor,
                        lockNow: lockNow,
                        pause: pause,
                        pauseUntilResumed: pauseUntilResumed,
                        resume: resume,
                        quit: quit
                    )
                case .devices:
                    DeviceSelectionView(scanner: scanner, deviceStore: deviceStore) { device in
                        deviceStore.select(device)
                        logger.add("Selected device: \(device.name), RSSI \(device.rssi.map(String.init) ?? "unknown")")
                        section = .overview
                    }
                case .settings:
                    SettingsView(settings: settings)
                case .logs:
                    LogsView(logger: logger)
                }
            }
            .frame(width: 780, height: 640)
        }
        .frame(width: 860, height: 640)
        .onAppear {
            scanner.startScanning()
        }
    }
}

private enum PopoverSection: String, CaseIterable, Identifiable {
    case overview
    case devices
    case settings
    case logs

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview:
            return "speedometer"
        case .devices:
            return "dot.radiowaves.left.and.right"
        case .settings:
            return "gearshape"
        case .logs:
            return "list.bullet.rectangle"
        }
    }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .devices:
            return "Devices"
        case .settings:
            return "Settings"
        case .logs:
            return "Logs"
        }
    }
}

private struct PopoverSidebar: View {
    @Binding var section: PopoverSection
    let status: ProximityStatus

    var body: some View {
        VStack(spacing: 12) {
            AppIconView(size: 42)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ForEach(PopoverSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(section == item ? .blue : .secondary)
                        .frame(width: 48, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(section == item ? Color.blue.opacity(0.16) : Color.clear)
                        )
                        .overlay(alignment: .leading) {
                            if section == item {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue)
                                    .frame(width: 3, height: 26)
                                    .offset(x: -7)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(item.title)
            }

            Spacer()

            Button {
                SupportLink.open()
            } label: {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 48, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.13))
                    )
            }
            .buttonStyle(.plain)
            .help("Buy me a coffee")

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .help(status.displayName)
                .padding(.bottom, 18)
        }
        .frame(width: 80, height: 640)
        .background(.ultraThinMaterial)
    }

    private var statusColor: Color {
        switch status {
        case .nearby:
            return .green
        case .weakSignal, .lockingPending:
            return .orange
        case .notFound, .locked, .bluetoothUnavailable:
            return .red
        case .paused:
            return .blue
        case .disabled:
            return .secondary
        }
    }
}

@MainActor
private struct PopoverOverviewView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var deviceStore: DeviceStore
    @ObservedObject var monitor: ProximityMonitor

    let lockNow: () -> Void
    let pause: (TimeInterval, String) -> Void
    let pauseUntilResumed: () -> Void
    let resume: () -> Void
    let quit: () -> Void

    var body: some View {
        AwaySurface {
            VStack(alignment: .leading, spacing: 16) {
                AwayHeader(
                    title: "AwayLock",
                    subtitle: "Bluetooth proximity protection for this Mac.",
                    systemImage: "lock.shield"
                ) {
                    StatusPill(text: monitor.status.displayName, systemImage: statusIcon, tint: statusColor)
                }

                HStack(spacing: 10) {
                    MetricTile(title: "Device", value: deviceStore.selectedDevice?.name ?? "None", systemImage: "iphone")
                    MetricTile(title: "RSSI", value: rssiText, systemImage: "antenna.radiowaves.left.and.right")
                    MetricTile(title: "Average", value: averageText, systemImage: "waveform.path.ecg")
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Protection enabled", isOn: $settings.isEnabled)
                            .toggleStyle(.switch)
                        Spacer()
                        if let countdown = monitor.countdownRemaining {
                            StatusPill(text: "\(Int(countdown.rounded(.up)))s", systemImage: "timer", tint: .orange)
                        }
                    }

                    if let pauseDescription = settings.pauseDescription() {
                        HStack {
                            Label(pauseDescription, systemImage: "pause.circle.fill")
                                .foregroundStyle(.blue)
                            Spacer()
                            Button("Resume", action: resume)
                                .controlSize(.small)
                        }
                    }
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 10) {
                    Button {
                        lockNow()
                    } label: {
                        Label("Lock Now", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Menu {
                        Button("5 minutes") { pause(5 * 60, "5 minutes") }
                        Button("15 minutes") { pause(15 * 60, "15 minutes") }
                        Button("30 minutes") { pause(30 * 60, "30 minutes") }
                        Button("1 hour") { pause(60 * 60, "1 hour") }
                        Button("Until resumed", action: pauseUntilResumed)
                    } label: {
                        Label("Pause", systemImage: "pause.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .menuStyle(.button)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected device")
                        .font(.headline)
                    Text(deviceSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Button("Quit", action: quit)
                        .controlSize(.small)
                }
            }
        }
    }

    private var rssiText: String {
        if let currentRssi = monitor.currentRssi {
            return "\(currentRssi) dBm"
        }

        if let lastKnownRssi = deviceStore.selectedDevice?.lastKnownRssi {
            return "\(lastKnownRssi) dBm"
        }

        return "Unknown"
    }

    private var averageText: String {
        guard let averageRssi = monitor.averageRssi else {
            return "Unknown"
        }
        return "\(Int(averageRssi.rounded())) dBm"
    }

    private var deviceSummary: String {
        guard let device = deviceStore.selectedDevice else {
            return "No device selected. Open Devices from the sidebar and choose a paired Bluetooth device."
        }

        return "\(device.name)\n\(device.identifier.uuidString)"
    }

    private var statusIcon: String {
        switch monitor.status {
        case .nearby:
            return "checkmark.circle.fill"
        case .weakSignal, .lockingPending:
            return "exclamationmark.triangle.fill"
        case .notFound, .bluetoothUnavailable:
            return "xmark.circle.fill"
        case .locked:
            return "lock.fill"
        case .paused:
            return "pause.circle.fill"
        case .disabled:
            return "power.circle"
        }
    }

    private var statusColor: Color {
        switch monitor.status {
        case .nearby:
            return .green
        case .weakSignal, .lockingPending:
            return .orange
        case .notFound, .locked, .bluetoothUnavailable:
            return .red
        case .paused:
            return .blue
        case .disabled:
            return .secondary
        }
    }
}

@MainActor
struct DeviceSelectionView: View {
    @ObservedObject var scanner: BluetoothScanner
    @ObservedObject var deviceStore: DeviceStore
    @State private var knownDevices = KnownBluetoothDeviceProvider.pairedDevices()

    let onSelect: (BluetoothDevice) -> Void

    private var visibleDevices: [BluetoothDevice] {
        scanner.devices.filter { device in
            KnownBluetoothDeviceProvider.isKnownDevice(device, knownDevices: knownDevices)
        }
    }

    var body: some View {
        AwaySurface {
            VStack(alignment: .leading, spacing: 16) {
                AwayHeader(
                    title: "Bluetooth Devices",
                    subtitle: "Choose a paired device for proximity locking.",
                    systemImage: "dot.radiowaves.left.and.right"
                ) {
                    HStack(spacing: 10) {
                        StatusPill(
                            text: scanner.availability.displayName,
                            systemImage: scanner.availability == .poweredOn ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                            tint: scanner.availability == .poweredOn ? .green : .orange
                        )
                        Button {
                            knownDevices = KnownBluetoothDeviceProvider.pairedDevices()
                            scanner.stopScanning()
                            scanner.startScanning()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }

                HStack(spacing: 10) {
                    MetricTile(title: "Visible", value: "\(visibleDevices.count)", systemImage: "sensor.tag.radiowaves.forward")
                    MetricTile(title: "Known", value: "\(knownDevices.count)", systemImage: "person.crop.circle.badge.checkmark")
                    MetricTile(title: "Selected", value: deviceStore.selectedDevice?.name ?? "None", systemImage: "checkmark.shield")
                }

                if visibleDevices.isEmpty {
                    EmptyStatePanel(
                        title: "No paired BLE devices found",
                        message: emptyStateDescription,
                        systemImage: "wave.3.right"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(visibleDevices) { device in
                                DeviceRowView(
                                    device: device,
                                    isSelected: deviceStore.selectedDevice?.identifier == device.identifier,
                                    onSelect: { onSelect(device) }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .onAppear {
            knownDevices = KnownBluetoothDeviceProvider.pairedDevices()
        }
    }

    private var emptyStateDescription: String {
        "Only devices already paired or known to this Mac are shown. Pair the target in macOS Bluetooth settings first, then refresh."
    }
}

@MainActor
private struct DeviceRowView: View {
    let device: BluetoothDevice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(signalColor.opacity(0.16))
                Image(systemName: isSelected ? "checkmark.shield.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(signalColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    if isSelected {
                        StatusPill(text: "Selected", systemImage: "checkmark", tint: .green)
                    }
                }

                HStack(spacing: 10) {
                    Label(device.rssi.map { "\($0) dBm" } ?? "RSSI unknown", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(signalColor)
                    Text(device.identifier.uuidString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption)
            }

            Spacer(minLength: 12)

            Button(isSelected ? "Selected" : "Select", action: onSelect)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSelected)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.green.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var signalColor: Color {
        guard let rssi = device.rssi else {
            return .secondary
        }

        if rssi >= -65 {
            return .green
        }
        if rssi >= -78 {
            return .orange
        }
        return .red
    }
}

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        AwaySurface {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AwayHeader(
                        title: "Settings",
                        subtitle: "Tune AwayLock for your space and device.",
                        systemImage: "slider.horizontal.3"
                    )

                    SettingsPanel(title: "Appearance", systemImage: "paintpalette") {
                        Text("Use System to follow macOS automatically, or force AwayLock into Light or Dark mode.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Picker("Theme", selection: $settings.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.displayName).tag(appearance)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    SettingsPanel(title: "General", systemImage: "switch.2") {
                        ToggleInfoRow(
                            title: "Enable proximity lock",
                            message: "Turns automatic locking on or off. Lock Now still remains available for manual testing.",
                            isOn: $settings.isEnabled
                        )
                        ToggleInfoRow(
                            title: "Launch at login",
                            message: "Starts AwayLock after you sign in, so protection is active without opening it manually.",
                            isOn: $settings.launchAtLogin
                        )
                        ToggleInfoRow(
                            title: "Show notifications",
                            message: "Shows lock, pause, and warning notifications when AwayLock changes state.",
                            isOn: $settings.showNotifications
                        )
                    }

                    SettingsPanel(title: "Detection", systemImage: "scope") {
                        StepperRow(
                            title: "Scan interval",
                            message: "How often AwayLock evaluates Bluetooth signal. Lower is more responsive; higher uses less work.",
                            value: "\(Int(settings.scanInterval)) s"
                        ) {
                            Stepper("", value: $settings.scanInterval, in: 1...10, step: 1)
                                .labelsHidden()
                        }
                        StepperRow(
                            title: "Missing timeout",
                            message: "Locks only after the selected device has been invisible for this long.",
                            value: "\(Int(settings.missingDeviceTimeout)) s"
                        ) {
                            Stepper("", value: $settings.missingDeviceTimeout, in: 5...120, step: 5)
                                .labelsHidden()
                        }
                        StepperRow(
                            title: "Weak signal timeout",
                            message: "Locks only after the averaged RSSI stays below the threshold for this long.",
                            value: "\(Int(settings.weakSignalTimeout)) s"
                        ) {
                            Stepper("", value: $settings.weakSignalTimeout, in: 5...120, step: 5)
                                .labelsHidden()
                        }
                        StepperRow(
                            title: "RSSI threshold",
                            message: "More negative is more tolerant. -70 dBm locks sooner; -80 dBm is safer against false locks.",
                            value: "\(settings.rssiThreshold) dBm"
                        ) {
                            Stepper("", value: $settings.rssiThreshold, in: -100 ... -40, step: 1)
                                .labelsHidden()
                        }
                        StepperRow(
                            title: "Average window",
                            message: "Number of RSSI readings averaged together. Higher smooths spikes but reacts slower.",
                            value: "\(settings.rssiAverageWindow) readings"
                        ) {
                            Stepper("", value: $settings.rssiAverageWindow, in: 1...20, step: 1)
                                .labelsHidden()
                        }
                        StepperRow(
                            title: "Cooldown after lock",
                            message: "Prevents repeated automatic lock attempts immediately after AwayLock triggers.",
                            value: "\(Int(settings.cooldownAfterLock)) s"
                        ) {
                            Stepper("", value: $settings.cooldownAfterLock, in: 10...600, step: 10)
                                .labelsHidden()
                        }
                    }

                    SettingsPanel(title: "Permissions", systemImage: "person.crop.circle.badge.checkmark") {
                        PermissionRow(
                            title: "Accessibility",
                            message: "Required for sending the macOS lock shortcut from AwayLock.",
                            systemImage: "hand.raised.fill",
                            actionTitle: "Open"
                        ) {
                            openAccessibilitySettings()
                        }
                        PermissionRow(
                            title: "Bluetooth",
                            message: "Required for scanning nearby paired BLE devices.",
                            systemImage: "dot.radiowaves.left.and.right",
                            actionTitle: "Open"
                        ) {
                            openBluetoothPrivacy()
                        }
                    }

                    SettingsPanel(title: "Support", systemImage: "cup.and.saucer") {
                        Text("AwayLock is free. If it saves you a few trips back to your Mac, you can support development.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        BuyMeCoffeeButton()
                    }
                }
            }
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openBluetoothPrivacy() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
struct LogsView: View {
    @ObservedObject var logger: EventLogger

    var body: some View {
        AwaySurface {
            VStack(alignment: .leading, spacing: 16) {
                AwayHeader(
                    title: "Recent Events",
                    subtitle: "The last operational messages from AwayLock.",
                    systemImage: "list.bullet.rectangle"
                ) {
                    StatusPill(text: "\(logger.events.count) / 200", systemImage: "clock.arrow.circlepath", tint: .blue)
                }

                if logger.events.isEmpty {
                    EmptyStatePanel(
                        title: "No events yet",
                        message: "AwayLock will show scan, signal, pause, and lock events here.",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(logger.events.reversed()) { event in
                                LogRowView(event: event)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private struct LogRowView: View {
        let event: LogEvent

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Text(LogsView.formatter.string(from: event.date))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .leading)

                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)

                Text(event.message)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        private var accentColor: Color {
            let message = event.message.lowercased()
            if message.contains("failed") || message.contains("not found") {
                return .red
            }
            if message.contains("paused") || message.contains("cooldown") || message.contains("weak") {
                return .orange
            }
            if message.contains("selected") || message.contains("started") || message.contains("succeeded") {
                return .green
            }
            return .blue
        }
    }
}

@MainActor
struct OnboardingView: View {
    var body: some View {
        AwaySurface {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    AppIconView(size: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("AwayLock")
                            .font(.largeTitle.weight(.bold))
                        Text("Lock your Mac when your trusted Bluetooth device leaves.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 10) {
                    OnboardingStep(
                        number: "1",
                        title: "Allow Bluetooth",
                        message: "AwayLock scans paired BLE devices to monitor signal strength.",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                    OnboardingStep(
                        number: "2",
                        title: "Approve Accessibility",
                        message: "Required so AwayLock can trigger the macOS lock shortcut.",
                        systemImage: "hand.raised.fill"
                    )
                    OnboardingStep(
                        number: "3",
                        title: "Select your device",
                        message: "Choose the phone, watch, or headphones that should keep this Mac unlocked.",
                        systemImage: "checkmark.shield.fill"
                    )
                    OnboardingStep(
                        number: "4",
                        title: "Tune sensitivity",
                        message: "Start with -75 dBm and adjust only if your environment needs it.",
                        systemImage: "slider.horizontal.3"
                    )
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button {
                        openBluetoothPrivacy()
                    } label: {
                        Label("Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                    }
                    Button {
                        openAccessibilitySettings()
                    } label: {
                        Label("Accessibility", systemImage: "hand.raised")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
    }

    private func openBluetoothPrivacy() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
private struct AwaySurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content()
                .padding(20)
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.03, green: 0.05, blue: 0.09),
                Color(nsColor: .windowBackgroundColor),
                Color(red: 0.06, green: 0.10, blue: 0.16)
            ]
        }

        return [
            Color(nsColor: .windowBackgroundColor),
            Color(red: 0.93, green: 0.97, blue: 1.00),
            Color(red: 0.98, green: 0.98, blue: 0.96)
        ]
    }
}

@MainActor
private struct AwayHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
            trailing()
        }
    }
}

private struct StatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let systemImage: String
    let content: () -> Content

    init(title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StepperRow<Control: View>: View {
    let title: String
    let message: String
    let value: String
    let control: () -> Control

    init(title: String, message: String, value: String, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.message = message
        self.value = value
        self.control = control
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 86, alignment: .trailing)
            control()
        }
    }
}

private struct ToggleInfoRow: View {
    let title: String
    let message: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Button(actionTitle, action: action)
                .controlSize(.small)
        }
    }
}

private enum SupportLink {
    static let profileURL = URL(string: "https://buymeacoffee.com/leosrehacek")
    static let buttonImageURL = URL(string: "https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=%E2%98%95&slug=leosrehacek&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff")

    static func open() {
        guard let url = profileURL else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct BuyMeCoffeeButton: View {
    var body: some View {
        Button {
            SupportLink.open()
        } label: {
            AsyncImage(url: SupportLink.buttonImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    fallbackLabel
                case .empty:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 217, height: 60)
                @unknown default:
                    fallbackLabel
                }
            }
            .frame(width: 217, height: 60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Buy me a coffee")
    }

    private var fallbackLabel: some View {
        HStack(spacing: 8) {
            Text("Buy me a coffee")
                .font(.system(size: 24, weight: .regular, design: .rounded))
            Text("☕")
                .font(.system(size: 21))
        }
        .foregroundStyle(.black)
        .frame(width: 217, height: 60)
        .background(Color(red: 1.0, green: 0.87, blue: 0.0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black, lineWidth: 1)
        }
    }
}

private struct EmptyStatePanel: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OnboardingStep: View {
    let number: String
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.16))
                Text(number)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 28, height: 28)

            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: iconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private var iconImage: NSImage {
        NSImage(named: "AppIcon") ?? NSApp.applicationIconImage
    }
}
