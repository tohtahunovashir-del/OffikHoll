import Foundation
import GRDB
@testable import Bloknot

enum TestSupport {
    static func database() throws -> DatabaseQueue {
        try DatabaseManager.makeInMemoryQueue()
    }

    /// Прокачивает run loop, чтобы `ValueObservation` успела доставить значение.
    @discardableResult
    static func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        if condition() { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            if condition() { return true }
        }
        return condition()
    }
}
