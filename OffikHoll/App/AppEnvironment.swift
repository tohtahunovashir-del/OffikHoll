import Foundation
import Combine
import GRDB

/// Owns the database and the long-living reactive stores.
final class AppEnvironment: ObservableObject {
    let database: DatabaseQueue
    let menuStore: MenuStore
    let floorStore: FloorStore
    let storageNote: String?

    init() {
        var queue: DatabaseQueue
        var note: String?
        do {
            queue = try AppDatabase.makeQueue()
        } catch {
            note = "Постоянное хранилище недоступно, данные сохранятся только до перезапуска."
            do {
                queue = try AppDatabase.makeInMemoryQueue()
            } catch {
                fatalError("OffikHoll: unable to open SQLite storage: \(error)")
            }
        }
        database = queue
        menuStore = MenuStore(database: queue)
        floorStore = FloorStore(database: queue)
        storageNote = note
    }
}
