import Foundation

public struct RSSIWindow: Equatable {
    public private(set) var values: [Int] = []
    public private(set) var size: Int

    public init(size: Int) {
        self.size = max(1, size)
    }

    public var average: Double? {
        guard !values.isEmpty else {
            return nil
        }

        let total = values.reduce(0, +)
        return Double(total) / Double(values.count)
    }

    public mutating func append(_ value: Int) {
        values.append(value)
        trimToSize()
    }

    public mutating func resize(_ newSize: Int) {
        size = max(1, newSize)
        trimToSize()
    }

    private mutating func trimToSize() {
        if values.count > size {
            values.removeFirst(values.count - size)
        }
    }
}
