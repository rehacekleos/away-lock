import AppKit
import Combine

@MainActor
public enum AwayLockApplication {
    private static var appDelegate: AppDelegate?

    public static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = AppContainer()
        self.container = container
        container.start()

        if container.settings.isFirstLaunch {
            container.showOnboarding()
            container.settings.markOnboardingSeen()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.stop()
    }
}

@MainActor
final class AppContainer {
    let settings: SettingsStore
    let deviceStore: DeviceStore
    let logger: EventLogger
    let notificationService: NotificationService
    let scanner: BluetoothScanner
    let lockService: LockService
    let monitor: ProximityMonitor
    let menuBarController: MenuBarController

    private var cancellables = Set<AnyCancellable>()

    init() {
        settings = SettingsStore()
        deviceStore = DeviceStore()
        logger = EventLogger()
        notificationService = NotificationService()
        scanner = BluetoothScanner(logger: logger)
        lockService = LockService(logger: logger, notificationService: notificationService)
        monitor = ProximityMonitor(
            scanner: scanner,
            deviceStore: deviceStore,
            settings: settings,
            lockService: lockService,
            logger: logger
        )
        menuBarController = MenuBarController(
            settings: settings,
            deviceStore: deviceStore,
            scanner: scanner,
            monitor: monitor,
            lockService: lockService,
            logger: logger
        )

        settings.$launchAtLogin
            .dropFirst()
            .sink { [logger] enabled in
                LaunchAtLoginService.setEnabled(enabled, logger: logger)
            }
            .store(in: &cancellables)

        settings.$appearance
            .sink { appearance in
                AppearanceService.apply(appearance)
            }
            .store(in: &cancellables)
    }

    func start() {
        AppearanceService.apply(settings.appearance)
        notificationService.requestAuthorizationIfNeeded(settings: settings.snapshot())
        scanner.startScanning()
        monitor.start()
        logger.add("AwayLock started")
    }

    func stop() {
        monitor.stop()
        scanner.stopScanning()
        logger.add("AwayLock stopped")
    }

    func showOnboarding() {
        menuBarController.showOnboarding()
    }
}
