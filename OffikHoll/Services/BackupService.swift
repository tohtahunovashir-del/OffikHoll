import Foundation
import GRDB

struct MenuExportCategory: Codable {
    var name: String
    var order: Int
    var icon: String
}

struct MenuExportItem: Codable {
    var name: String
    var price: Double
    var category: String
    var details: String
    var isAvailable: Bool
}

struct MenuExportDocument: Codable {
    var app: String
    var version: Int
    var exportedAt: Date
    var categories: [MenuExportCategory]
    var items: [MenuExportItem]
}

struct BackupDocument: Codable {
    var app: String
    var version: Int
    var exportedAt: Date
    var categories: [Category]
    var items: [MenuItem]
    var tables: [RestaurantTable]
    var orders: [Order]
    var orderItems: [OrderItem]
}

struct RestoreSummary {
    var categories: Int
    var items: Int
    var tables: Int
    var orders: Int

    var text: String {
        "Восстановлено: категорий \(categories), блюд \(items), столов \(tables), заказов \(orders)."
    }
}

enum BackupError: LocalizedError {
    case unreadable
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "Файл повреждён или имеет неверный формат."
        case .unsupportedVersion(let version):
            return "Версия резервной копии \(version) не поддерживается."
        }
    }
}

/// JSON / CSV export and full offline backup. No network involved.
enum BackupService {
    static let currentVersion = 1

    // MARK: - Menu export

    static func makeMenuDocument(categories: [Category], items: [MenuItem]) -> MenuExportDocument {
        let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        return MenuExportDocument(
            app: "OffikHoll",
            version: currentVersion,
            exportedAt: Date(),
            categories: categories.map {
                MenuExportCategory(name: $0.name, order: $0.order, icon: $0.icon)
            },
            items: items.map {
                MenuExportItem(
                    name: $0.name,
                    price: $0.price,
                    category: names[$0.categoryId] ?? "Без категории",
                    details: $0.details,
                    isAvailable: $0.isAvailable
                )
            }
        )
    }

    static func writeMenuJSON(categories: [Category], items: [MenuItem]) throws -> URL {
        let document = makeMenuDocument(categories: categories, items: items)
        return try writeJSON(document, prefix: "OffikHoll-menu")
    }

    static func writeMenuCSV(categories: [Category], items: [MenuItem]) throws -> URL {
        let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        var rows: [[String]] = [["Категория", "Блюдо", "Цена", "Описание", "Доступно"]]
        for item in items {
            rows.append([
                names[item.categoryId] ?? "Без категории",
                item.name,
                csvPrice(item.price),
                item.details,
                item.isAvailable ? "да" : "нет"
            ])
        }
        let url = makeURL(prefix: "OffikHoll-menu", ext: "csv")
        try csvData(rows).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Scan drafts export

    static func writeScanDraftsJSON(_ drafts: [ScanDraft]) throws -> URL {
        struct DraftExport: Codable {
            var name: String
            var price: Double
            var category: String
            var portion: String
            var page: Int
            var confidence: Double
        }
        let payload = drafts.map {
            DraftExport(
                name: $0.name,
                price: $0.price ?? 0,
                category: $0.categoryName,
                portion: $0.portion,
                page: $0.pageIndex + 1,
                confidence: $0.confidence
            )
        }
        return try writeJSON(payload, prefix: "OffikHoll-scan")
    }

    static func writeScanDraftsCSV(_ drafts: [ScanDraft]) throws -> URL {
        var rows: [[String]] = [["Категория", "Блюдо", "Цена", "Порция", "Страница"]]
        for draft in drafts {
            rows.append([
                draft.categoryName,
                draft.name,
                csvPrice(draft.price ?? 0),
                draft.portion,
                String(draft.pageIndex + 1)
            ])
        }
        let url = makeURL(prefix: "OffikHoll-scan", ext: "csv")
        try csvData(rows).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Full backup

    static func writeFullBackup(database: DatabaseQueue) throws -> URL {
        let document = try database.read { db -> BackupDocument in
            BackupDocument(
                app: "OffikHoll",
                version: currentVersion,
                exportedAt: Date(),
                categories: try Category.order(Category.Columns.sortOrder).fetchAll(db),
                items: try MenuItem.order(MenuItem.Columns.name).fetchAll(db),
                tables: try RestaurantTable.order(RestaurantTable.Columns.number).fetchAll(db),
                orders: try Order.order(Order.Columns.createdAt).fetchAll(db),
                orderItems: try OrderItem.order(OrderItem.Columns.createdAt).fetchAll(db)
            )
        }
        return try writeJSON(document, prefix: "OffikHoll-backup")
    }

    static func restore(database: DatabaseQueue, from url: URL) throws -> RestoreSummary {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: BackupDocument
        do {
            document = try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
        guard document.version <= currentVersion else {
            throw BackupError.unsupportedVersion(document.version)
        }

        return try database.write { db -> RestoreSummary in
            try db.execute(sql: "DELETE FROM order_items")
            try db.execute(sql: "DELETE FROM orders")
            try db.execute(sql: "DELETE FROM menu_items")
            try db.execute(sql: "DELETE FROM categories")
            try db.execute(sql: "DELETE FROM tables")

            for category in document.categories { try category.insert(db) }
            for item in document.items { try item.insert(db) }
            for table in document.tables { try table.insert(db) }
            for order in document.orders { try order.insert(db) }
            for line in document.orderItems { try line.insert(db) }

            try db.execute(sql: """
                UPDATE tables SET status = 'free', currentOrderId = NULL;
                """)
            let openOrders = try Order
                .filter(Order.Columns.status != OrderStatus.paid.rawValue)
                .fetchAll(db)
            for order in openOrders {
                try db.execute(
                    sql: "UPDATE tables SET status = ?, currentOrderId = ? WHERE id = ?",
                    arguments: [TableStatus.occupied.rawValue, order.id, order.tableId]
                )
            }

            return RestoreSummary(
                categories: document.categories.count,
                items: document.items.count,
                tables: document.tables.count,
                orders: document.orders.count
            )
        }
    }

    // MARK: - Files

    private static func writeJSON<T: Encodable>(_ value: T, prefix: String) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let url = makeURL(prefix: prefix, ext: "json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func makeURL(prefix: String, ext: String) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "\(prefix)-\(formatter.string(from: Date())).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private static func csvPrice(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    private static func csvData(_ rows: [[String]]) -> Data {
        let text = rows
            .map { row in row.map(csvField).joined(separator: ";") }
            .joined(separator: "\r\n")
        return Data(("\u{FEFF}" + text).utf8)
    }

    private static func csvField(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
