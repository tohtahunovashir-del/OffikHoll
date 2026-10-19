import Foundation
import GRDB
@testable import OffikHoll

/// Small helpers shared by the unit tests.
enum TestSupport {
    /// Fresh, migrated, seeded database — exactly what the app opens on a
    /// first launch, but in memory so tests never touch the file system.
    static func makeDatabase() throws -> DatabaseQueue {
        try AppDatabase.makeInMemoryQueue()
    }

    /// Pumps the run loop so main-queue `ValueObservation` callbacks are
    /// delivered while a test waits for the reactive store to update.
    @discardableResult
    static func waitUntil(
        timeout: TimeInterval = 5,
        _ condition: () -> Bool
    ) -> Bool {
        if condition() { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            if condition() { return true }
        }
        return condition()
    }
}
