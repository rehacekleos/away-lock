import AppKit

@MainActor
enum AppearanceService {
    static func apply(_ appearance: AppAppearance) {
        let nsAppearance: NSAppearance?

        switch appearance {
        case .system:
            nsAppearance = nil
        case .light:
            nsAppearance = NSAppearance(named: .aqua)
        case .dark:
            nsAppearance = NSAppearance(named: .darkAqua)
        }

        NSApp.appearance = nsAppearance
        for window in NSApp.windows {
            window.appearance = nsAppearance
        }
    }
}
