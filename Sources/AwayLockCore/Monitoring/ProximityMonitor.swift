import Combine
import Foundation

@MainActor
public final class ProximityMonitor: ObservableObject {
    @Published public private(set) var status: ProximityStatus = .notFound
    @Published public private(set) var currentRssi: Int?
    @Published public private(set) var averageRssi: Double?
    @Published public private(set) var countdownRemaining: TimeInterval?

    private let scanner: BluetoothScanner
    private let deviceStore: DeviceStore
    private let settings: SettingsStore
    private let lockService: LockService
    private let logger: EventLogger

    private var timer: Timer?
    private var engine: ProximityDecisionEngine
    private var lastLoggedStatus: ProximityStatus?
    private var cancellables = Set<AnyCancellable>()

    public init(
        scanner: BluetoothScanner,
        deviceStore: DeviceStore,
        settings: SettingsStore,
        lockService: LockService,
        logger: EventLogger
    ) {
        self.scanner = scanner
        self.deviceStore = deviceStore
        self.settings = settings
        self.lockService = lockService
        self.logger = logger
        engine = ProximityDecisionEngine(windowSize: settings.rssiAverageWindow)

        settings.$scanInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.restartTimer()
            }
            .store(in: &cancellables)
    }

    public func start() {
        restartTimer()
        evaluate()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func evaluate(now: Date = Date()) {
        settings.expirePauseIfNeeded(now: now)

        let snapshot = settings.snapshot()
        let isPaused = settings.isPaused(now: now)

        guard snapshot.isEnabled else {
            applyDecision(
                ProximityDecision(
                    status: .disabled,
                    currentRssi: nil,
                    averageRssi: nil,
                    countdownRemaining: nil,
                    lockReason: nil
                )
            )
            return
        }

        guard !isPaused else {
            applyDecision(
                ProximityDecision(
                    status: .paused,
                    currentRssi: nil,
                    averageRssi: nil,
                    countdownRemaining: nil,
                    lockReason: nil
                )
            )
            return
        }

        guard let selectedDevice = deviceStore.selectedDevice else {
            engine.resetTransientState(windowSize: snapshot.rssiAverageWindow)
            applyDecision(
                ProximityDecision(
                    status: .notFound,
                    currentRssi: nil,
                    averageRssi: nil,
                    countdownRemaining: nil,
                    lockReason: nil
                )
            )
            return
        }

        guard scanner.availability == .poweredOn else {
            engine.resetTransientState(windowSize: snapshot.rssiAverageWindow)
            applyDecision(
                ProximityDecision(
                    status: .bluetoothUnavailable,
                    currentRssi: nil,
                    averageRssi: nil,
                    countdownRemaining: nil,
                    lockReason: nil
                )
            )
            return
        }

        let freshnessWindow = max(snapshot.scanInterval * 3, 6)
        scanner.removeStaleDevices(olderThan: max(freshnessWindow * 4, 30), now: now)

        let input: ProximityInput
        if let device = scanner.device(identifier: selectedDevice.identifier),
           now.timeIntervalSince(device.lastSeen) <= freshnessWindow,
           let rssi = device.rssi {
            input = .found(rssi: rssi)
            deviceStore.updateLastKnownRssi(rssi)
            logger.add("Device found: \(device.name), RSSI \(rssi)")
        } else {
            input = .missing
        }

        var decision = engine.evaluate(
            input: input,
            now: now,
            settings: snapshot,
            isPaused: false,
            isInCooldown: lockService.isInCooldown(now: now)
        )

        if let lockReason = decision.lockReason {
            lockService.lock(reason: lockReason, settings: snapshot)
            decision = ProximityDecision(
                status: .locked,
                currentRssi: decision.currentRssi,
                averageRssi: decision.averageRssi,
                countdownRemaining: nil,
                lockReason: nil
            )
        }

        applyDecision(decision)
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(settings.scanInterval, 1), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluate()
            }
        }
    }

    private func applyDecision(_ decision: ProximityDecision) {
        status = decision.status
        currentRssi = decision.currentRssi
        averageRssi = decision.averageRssi
        countdownRemaining = decision.countdownRemaining

        if lastLoggedStatus != decision.status {
            lastLoggedStatus = decision.status
            logger.add("Status changed: \(decision.status.displayName)")
        }

        if let average = decision.averageRssi {
            logger.add("RSSI average: \(Int(average.rounded()))")
        }
    }
}
