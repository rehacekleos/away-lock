import Foundation

public struct LogEvent: Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let message: String

    public init(id: UUID = UUID(), date: Date = Date(), message: String) {
        self.id = id
        self.date = date
        self.message = message
    }
}

@MainActor
public final class EventLogger: ObservableObject {
    @Published public private(set) var events: [LogEvent] = []

    private let maximumEvents: Int

    public init(maximumEvents: Int = 200) {
        self.maximumEvents = maximumEvents
    }

    public func add(_ message: String, date: Date = Date()) {
        events.append(LogEvent(date: date, message: message))

        if events.count > maximumEvents {
            events.removeFirst(events.count - maximumEvents)
        }
    }
}
