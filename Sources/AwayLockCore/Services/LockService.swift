import ApplicationServices
import Foundation

@MainActor
public final class LockService: ObservableObject {
    @Published public private(set) var cooldownUntil: Date?

    private let logger: EventLogger
    private let notificationService: NotificationService

    public init(logger: EventLogger, notificationService: NotificationService) {
        self.logger = logger
        self.notificationService = notificationService
    }

    public func isInCooldown(now: Date = Date()) -> Bool {
        guard let cooldownUntil else {
            return false
        }
        return cooldownUntil > now
    }

    public func lock(reason: LockReason, settings: ProximitySettingsSnapshot) {
        let now = Date()
        let bypassCooldown = reason == .manual

        guard bypassCooldown || !isInCooldown(now: now) else {
            logger.add("Lock skipped because cooldown is active")
            return
        }

        logger.add("Lock triggered: \(reason.displayName)")

        if runLockCommands() {
            cooldownUntil = now.addingTimeInterval(settings.cooldownAfterLock)
            logger.add("Cooldown started")
            notificationService.send(
                title: "AwayLock",
                body: "Mac locked because \(reason.notificationDescription).",
                settings: settings
            )
        } else {
            logger.add("Lock failed: all lock commands failed")
        }
    }

    public func lockNow(settings: ProximitySettingsSnapshot) {
        lock(reason: .manual, settings: settings)
    }

    private func runLockCommands() -> Bool {
        for command in LockCommand.all {
            do {
                try command.run()
                logger.add("Lock command succeeded: \(command.name)")
                return true
            } catch {
                logger.add("Lock command failed: \(command.name): \(error.localizedDescription)")
            }
        }

        return false
    }
}

private enum LockCommand {
    case embeddedAppleScriptShortcut
    case nativeShortcut
    case executable(name: String, executablePath: String, arguments: [String])

    static let all: [LockCommand] = [
        .embeddedAppleScriptShortcut,
        .nativeShortcut,
        .executable(
            name: "CGSession suspend",
            executablePath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
            arguments: ["-suspend"]
        ),
        .executable(
            name: "System lock shortcut through osascript",
            executablePath: "/usr/bin/osascript",
            arguments: [
                "-e",
                "tell application \"System Events\" to key code 12 using {control down, command down}"
            ]
        )
    ]

    var name: String {
        switch self {
        case .embeddedAppleScriptShortcut:
            return "Embedded AppleScript lock shortcut"
        case .nativeShortcut:
            return "Native system lock shortcut"
        case .executable(let name, _, _):
            return name
        }
    }

    func run() throws {
        switch self {
        case .embeddedAppleScriptShortcut:
            try EmbeddedAppleScriptLockShortcut.run()
        case .nativeShortcut:
            try NativeLockShortcut.run()
        case .executable(_, let executablePath, let arguments):
            try runExecutable(executablePath: executablePath, arguments: arguments)
        }
    }

    private func runExecutable(executablePath: String, arguments: [String]) throws {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw LockCommandError.executableNotFound(executablePath)
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw LockCommandError.nonZeroExit(
                status: process.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                error: error.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

private enum EmbeddedAppleScriptLockShortcut {
    static func run() throws {
        let source = """
        tell application "System Events"
            key code 12 using {control down, command down}
        end tell
        """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw LockCommandError.cannotCreateAppleScript
        }

        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
            let number = errorInfo[NSAppleScript.errorNumber] as? NSNumber
            let detail = [number.map { "code \($0)" }, message]
                .compactMap { $0 }
                .joined(separator: ": ")
            throw LockCommandError.appleScriptFailed(detail)
        }
    }
}

private enum NativeLockShortcut {
    private static let qKeyCode: CGKeyCode = 12

    static func run() throws {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary

        guard AXIsProcessTrustedWithOptions(options) else {
            throw LockCommandError.accessibilityPermissionRequired(bundlePath: Bundle.main.bundlePath)
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: qKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: qKeyCode, keyDown: false) else {
            throw LockCommandError.cannotCreateKeyboardEvent
        }

        let flags: CGEventFlags = [.maskControl, .maskCommand]
        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

private enum LockCommandError: LocalizedError {
    case accessibilityPermissionRequired(bundlePath: String)
    case appleScriptFailed(String)
    case cannotCreateAppleScript
    case cannotCreateKeyboardEvent
    case executableNotFound(String)
    case nonZeroExit(status: Int32, output: String, error: String)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired(let bundlePath):
            return "Accessibility permission is required for the currently running AwayLock at \(bundlePath). Remove old AwayLock entries from Accessibility, add this app again, then try Lock Now."
        case .appleScriptFailed(let detail):
            return detail.isEmpty ? "Embedded AppleScript failed" : detail
        case .cannotCreateAppleScript:
            return "Could not create embedded AppleScript"
        case .cannotCreateKeyboardEvent:
            return "Could not create the native lock keyboard event"
        case .executableNotFound(let path):
            return "The executable does not exist at \(path)"
        case .nonZeroExit(let status, let output, let error):
            let detail = [error, output]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if detail.isEmpty {
                return "Command exited with status \(status)"
            }

            return "Command exited with status \(status): \(detail)"
        }
    }
}
