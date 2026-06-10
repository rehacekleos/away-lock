import Foundation
import ServiceManagement

@MainActor
public enum LaunchAtLoginService {
    public static func setEnabled(_ enabled: Bool, logger: EventLogger) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    logger.add("Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    logger.add("Launch at login disabled")
                }
            } catch {
                logger.add("Launch at login update failed: \(error.localizedDescription)")
            }
        } else {
            logger.add("Launch at login requires macOS 13 or newer")
        }
    }
}
