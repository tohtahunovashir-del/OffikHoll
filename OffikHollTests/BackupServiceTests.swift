import XCTest
import GRDB
@testable import OffikHoll

/// Export/restore is the only way waiters get data off the device, so the
/// round-trip is verified against a real (in-memory) SQLite database.
final class BackupServiceTests: XCTestCase {
    private struct Counts {
        var categories: Int
        var items: Int
        var tables: Int
        var orders: Int
        var orderItems: Int
    }

    private func counts(in db: DatabaseQueue) throws -> Counts {
        try db.read { db in
            Counts(
                categories: try Category.fetchCount(db),
                items: try MenuItem.fetchCount(db),
                tables: try RestaurantTable.fetchCount(db),
                orders: try Order.fetchCount(db),
                orderItems: try OrderItem.fetchCount(db)
            )
        }
    }

    // MARK: - Full backup

    func testFullBackupRestoresEveryRow() throws {
        let source = try TestSupport.makeDatabase()
        let original = try counts(in: source)

        XCTAssertGreaterThan(original.categories, 0, "демо-меню должно заполнить базу")
        XCTAssertGreaterThan(original.items, 0)
        XCTAssertGreaterThan(original.tables, 0)

        let url = try BackupService.writeFullBackup(database: source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let target = try TestSupport.makeDatabase()
        let summary = try BackupService.restore(database: target, from: url)
        let restored = try counts(in: target)

        XCTAssertEqual(summary.categories, original.categories)
        XCTAssertEqual(summary.items, original.items)
        XCTAssertEqual(summary.tables, original.tables)
        XCTAssertEqual(restored.categories, original.categories)
        XCTAssertEqual(restored.items, original.items)
        XCTAssertEqual(restored.tables, original.tables)
        XCTAssertEqual(restored.orders, original.orders)
        XCTAssertEqual(restored.orderItems, original.orderItems)
    }

    func testFullBackupRestoreKeepsMenuContent() throws {
        let source = try TestSupport.makeDatabase()
        let url = try BackupService.writeFullBackup(database: source)

        let target = try TestSupport.makeDatabase()
        _ = try BackupService.restore(database: target, from: url)

        let sourceNames = try source.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM menu_items ORDER BY name")
        }
        let targetNames = try target.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM menu_items ORDER BY name")
        }
        XCTAssertEqual(sourceNames, targetNames)
        XCTAssertTrue(targetNames.contains("Цезарь с курицей"))
    }

    func testRestoreReplacesExistingContent() throws {
        let source = try TestSupport.makeDatabase()
        let url = try BackupService.writeFullBackup(database: source)

        let target = try TestSupport.makeDatabase()
        try target.write { db in
            // Foreign keys are enforced, so the extra dish reuses a real category.
            let categoryId = try XCTUnwrap(try Category.fetchOne(db)?.id)
            try MenuItem(name: "Лишнее блюдо", price: 1, categoryId: categoryId).insert(db)
        }
        _ = try BackupService.restore(database: target, from: url)

        let leftovers = try target.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM menu_items WHERE name = 'Лишнее блюдо'") ?? -1
        }
        XCTAssertEqual(leftovers, 0, "восстановление должно заменить данные, а не смешаться с ними")
    }

    func testRestoreRejectsBrokenFile() throws {
        let target = try TestSupport.makeDatabase()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OffikHoll-broken-\(UUID().uuidString).json")
        try Data("not a backup".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try BackupService.restore(database: target, from: url)) { error in
            XCTAssertEqual((error as? BackupError)?.errorDescription, "Файл повреждён или имеет неверный формат.")
        }
    }

    // MARK: - Menu export

    func testMenuJSONDocument() throws {
        let db = try TestSupport.makeDatabase()
        let data = try db.read { db in
            (try Category.order(Category.Columns.sortOrder).fetchAll(db), try MenuItem.fetchAll(db))
        }

        let url = try BackupService.writeMenuJSON(categories: data.0, items: data.1)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(MenuExportDocument.self, from: Data(contentsOf: url))

        XCTAssertEqual(document.app, "OffikHoll")
        XCTAssertEqual(document.version, BackupService.currentVersion)
        XCTAssertEqual(document.categories.count, data.0.count)
        XCTAssertEqual(document.items.count, data.1.count)
        XCTAssertTrue(document.items.allSatisfy { !$0.name.isEmpty && $0.price > 0 })
        XCTAssertTrue(document.items.allSatisfy { $0.category != "Без категории" })
    }

    func testMenuCSVFormat() throws {
        let db = try TestSupport.makeDatabase()
        let data = try db.read { db in
            (try Category.order(Category.Columns.sortOrder).fetchAll(db), try MenuItem.fetchAll(db))
        }

        let url = try BackupService.writeMenuCSV(categories: data.0, items: data.1)
        let raw = try Data(contentsOf: url)

        XCTAssertEqual(Array(raw.prefix(3)), [0xEF, 0xBB, 0xBF], "UTF-8 BOM нужен для Excel")

        let text = String(decoding: raw, as: UTF8.self)
        XCTAssertTrue(text.contains("\"Категория\";\"Блюдо\";\"Цена\";\"Описание\";\"Доступно\""))
        XCTAssertTrue(text.contains("\r\n"), "строки разделены CRLF")
        XCTAssertTrue(text.contains("390,00"), "цены с десятичной запятой")
        XCTAssertTrue(text.contains("\"да\""), "флаг доступности")
    }

    // MARK: - Scan drafts export

    func testScanDraftsExport() throws {
        let drafts = [
            ScanDraft(
                name: "Цезарь",
                priceText: "520,50",
                categoryName: "Салаты",
                portion: "230 г",
                confidence: 0.9
            ),
            ScanDraft(
                name: "Борщ",
                priceText: "420",
                categoryName: "Супы",
                confidence: 0.4
            )
        ]

        let csvURL = try BackupService.writeScanDraftsCSV(drafts)
        let csv = try String(contentsOf: csvURL, encoding: .utf8)
        XCTAssertTrue(csv.contains("520,50"))
        XCTAssertTrue(csv.contains("Салаты"))

        let jsonURL = try BackupService.writeScanDraftsJSON(drafts)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [[String: Any]]
        XCTAssertEqual(json?.count, 2)
        XCTAssertEqual(json?.first?["name"] as? String, "Цезарь")
        XCTAssertEqual(json?.first?["page"] as? Int, 1)
    }
}
