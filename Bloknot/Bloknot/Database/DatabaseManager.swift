import Foundation
import GRDB

/// Единственный владелец SQLite-очереди. Приложение полностью офлайн,
/// GRDB — источник истины, экраны обновляются через `ValueObservation`.
final class DatabaseManager {
    static let shared = DatabaseManager()

    let database: DatabaseQueue

    private init() {
        if let queue = try? DatabaseManager.makePersistentQueue() {
            database = queue
        } else if let memory = try? DatabaseManager.makeInMemoryQueue() {
            database = memory
        } else {
            fatalError("Bloknot: не удалось открыть локальную базу данных")
        }
    }

    // MARK: - Factories

    static func makePersistentQueue() throws -> DatabaseQueue {
        let fileManager = FileManager.default
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = support.appendingPathComponent("Bloknot", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("bloknot.sqlite")
        let queue = try DatabaseQueue(path: url.path)
        try migrate(queue)
        return queue
    }

    static func makeInMemoryQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        try migrate(queue)
        return queue
    }

    // MARK: - Schema

    private static func migrate(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_schema") { db in
            try db.execute(sql: """
                CREATE TABLE categories (
                    id BLOB PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    sortOrder INTEGER NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL
                );

                CREATE TABLE menu_items (
                    id BLOB PRIMARY KEY NOT NULL,
                    categoryId BLOB NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
                    name TEXT NOT NULL,
                    price DOUBLE NOT NULL,
                    isAvailable BOOLEAN NOT NULL DEFAULT 1,
                    createdAt DATETIME NOT NULL
                );

                CREATE INDEX idx_menu_items_category ON menu_items(categoryId);

                CREATE TABLE tables (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    number INTEGER NOT NULL,
                    zone TEXT NOT NULL DEFAULT 'Основной зал',
                    seats INTEGER NOT NULL DEFAULT 2
                );

                CREATE UNIQUE INDEX idx_tables_number ON tables(number);

                CREATE TABLE orders (
                    id BLOB PRIMARY KEY NOT NULL,
                    tableId INTEGER NOT NULL REFERENCES tables(id) ON DELETE CASCADE,
                    status TEXT NOT NULL DEFAULT 'open',
                    createdAt DATETIME NOT NULL,
                    closedAt DATETIME,
                    guests INTEGER NOT NULL DEFAULT 2
                );

                CREATE INDEX idx_orders_table ON orders(tableId);
                CREATE INDEX idx_orders_status ON orders(status);

                CREATE TABLE order_items (
                    id BLOB PRIMARY KEY NOT NULL,
                    orderId BLOB NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
                    menuItemId BLOB NOT NULL,
                    name TEXT NOT NULL,
                    price DOUBLE NOT NULL,
                    quantity INTEGER NOT NULL DEFAULT 1,
                    isSent BOOLEAN NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL
                );

                CREATE INDEX idx_order_items_order ON order_items(orderId);
                """)
        }

        migrator.registerMigration("v2_seed") { db in
            try SeedData.seed(db)
        }

        try migrator.migrate(queue)
    }
}
