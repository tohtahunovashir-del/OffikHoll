import Foundation
import GRDB
import Combine
import UIKit

@MainActor
final class RestaurantStore: ObservableObject {
    @Published private(set) var categories: [Category] = []
    @Published private(set) var menuItems: [MenuItem] = []
    @Published private(set) var tables: [DiningTable] = []
    @Published private(set) var tableTotals: [Int: Double] = [:]
    @Published private(set) var activeOrder: Order?
    @Published private(set) var orderItems: [OrderItem] = []
    @Published var selectedCategoryID: UUID?
    @Published var errorMessage: String?

    private let database: DatabaseQueue

    init() {
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("OffikHoll", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            database = try DatabaseQueue(path: folder.appendingPathComponent("restaurant.sqlite").path)
            var migrator = DatabaseMigrator()
            migrator.registerMigration("initial-schema") { db in
                try db.create(table: "categories") { t in
                    t.column("id", .text).primaryKey()
                    t.column("name", .text).notNull().unique()
                    t.column("sortOrder", .integer).notNull()
                }
                try db.create(table: "menuItems") { t in
                    t.column("id", .text).primaryKey()
                    t.column("name", .text).notNull()
                    t.column("price", .double).notNull()
                    t.column("categoryId", .text).notNull().references("categories", onDelete: .cascade)
                }
                try db.create(table: "diningTables") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("number", .integer).notNull().unique()
                    t.column("status", .text).notNull()
                    t.column("currentOrderId", .text)
                }
                try db.create(table: "orders") { t in
                    t.column("id", .text).primaryKey()
                    t.column("tableId", .integer).notNull()
                    t.column("status", .text).notNull()
                    t.column("totalAmount", .double).notNull()
                    t.column("createdAt", .datetime).notNull()
                }
                try db.create(table: "orderItems") { t in
                    t.column("id", .text).primaryKey()
                    t.column("orderId", .text).notNull().references("orders", onDelete: .cascade)
                    t.column("menuItemId", .text).notNull()
                    t.column("quantity", .integer).notNull()
                    t.column("itemName", .text).notNull()
                    t.column("unitPrice", .double).notNull()
                }
            }
            try migrator.migrate(database)
            seedIfNeeded()
            refresh()
        } catch {
            fatalError("Не удалось открыть локальную базу данных: \(error)")
        }
    }

    func refresh() {
        do {
            categories = try Category.fetchAll(database, order: [Column("sortOrder").asc, Column("name").asc])
            menuItems = try MenuItem.fetchAll(database, order: [Column("name").asc])
            tables = try DiningTable.fetchAll(database, order: [Column("number").asc])
            tableTotals = Dictionary(uniqueKeysWithValues: try Order.fetchAll(database).filter { $0.status != .paid }.map { ($0.tableId, $0.totalAmount) })
            if selectedCategoryID == nil || !categories.contains(where: { $0.id == selectedCategoryID }) {
                selectedCategoryID = categories.first?.id
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func seedIfNeeded() {
        do {
            try database.write { db in
                if try Category.fetchCount(db) == 0 {
                    let samples = ["Закуски", "Салаты", "Горячее", "Десерты", "Напитки"]
                    for (index, name) in samples.enumerated() {
                        try Category(id: UUID(), name: name, order: index).insert(db)
                    }
                }
                let existingTables = try DiningTable.fetchCount(db)
                if existingTables == 0 {
                    for number in 1...12 {
                        try DiningTable(id: number, number: number, status: .free, currentOrderId: nil).insert(db)
                    }
                }
                if try MenuItem.fetchCount(db) == 0 {
                    let categoryRows = try Category.fetchAll(db)
                    let examples: [(String, Double, String)] = [
                        ("Брускетта с томатами", 420, "Закуски"), ("Тартар из говядины", 690, "Закуски"),
                        ("Цезарь с курицей", 590, "Салаты"), ("Салат с креветками", 740, "Салаты"),
                        ("Паста карбонара", 680, "Горячее"), ("Стейк рибай", 1890, "Горячее"),
                        ("Чизкейк", 390, "Десерты"), ("Морс ягодный", 240, "Напитки")
                    ]
                    for (name, price, categoryName) in examples {
                        if let category = categoryRows.first(where: { $0.name == categoryName }) {
                            try MenuItem(id: UUID(), name: name, price: price, categoryId: category.id).insert(db)
                        }
                    }
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func openTable(_ table: DiningTable) {
        do {
            try database.write { db in
                var selected = try DiningTable.fetchOne(db, key: table.id) ?? table
                if let existingID = selected.currentOrderId,
                   let existing = try Order.fetchOne(db, key: existingID), existing.status != .paid {
                    activeOrder = existing
                } else {
                    let order = Order(id: UUID(), tableId: table.id, status: .active, totalAmount: 0, createdAt: Date())
                    try order.insert(db)
                    selected.status = .occupied
                    selected.currentOrderId = order.id
                    try selected.update(db)
                    activeOrder = order
                }
            }
            loadOrderItems()
            refresh()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch { errorMessage = error.localizedDescription }
    }

    func add(_ item: MenuItem) {
        guard let order = activeOrder else { return }
        do {
            try database.write { db in
                if var existing = try OrderItem.filter(Column("orderId") == order.id && Column("menuItemId") == item.id).fetchOne(db) {
                    existing.quantity += 1
                    try existing.update(db)
                } else {
                    try OrderItem(id: UUID(), orderId: order.id, menuItemId: item.id, quantity: 1, itemName: item.name, unitPrice: item.price).insert(db)
                }
                try updateOrderTotal(order.id, db: db)
            }
            loadOrderItems()
            refresh()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch { errorMessage = error.localizedDescription }
    }

    func changeQuantity(_ item: OrderItem, by delta: Int) {
        guard let order = activeOrder else { return }
        do {
            try database.write { db in
                var updated = item
                updated.quantity += delta
                if updated.quantity <= 0 { try updated.delete(db) } else { try updated.update(db) }
                try updateOrderTotal(order.id, db: db)
            }
            loadOrderItems()
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    private func updateOrderTotal(_ id: UUID, db: Database) throws {
        let rows = try OrderItem.filter(Column("orderId") == id).fetchAll(db)
        guard var order = try Order.fetchOne(db, key: id) else { return }
        order.totalAmount = rows.reduce(0) { $0 + Double($1.quantity) * $1.unitPrice }
        try order.update(db)
        activeOrder = order
    }

    func loadOrderItems() {
        guard let order = activeOrder else { orderItems = []; return }
        do { orderItems = try OrderItem.filter(Column("orderId") == order.id).fetchAll(database) }
        catch { errorMessage = error.localizedDescription }
    }

    func sendToKitchen() {
        guard var order = activeOrder else { return }
        do {
            try database.write { db in
                order.status = .sent
                try order.update(db)
            }
            activeOrder = order
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { errorMessage = error.localizedDescription }
    }

    func payAndClose() {
        guard var order = activeOrder else { return }
        do {
            try database.write { db in
                order.status = .paid
                try order.update(db)
                if var table = try DiningTable.fetchOne(db, key: order.tableId) {
                    table.status = .free
                    table.currentOrderId = nil
                    try table.update(db)
                }
            }
            activeOrder = nil
            orderItems = []
            refresh()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { errorMessage = error.localizedDescription }
    }

    func saveCategory(name: String, editing: Category? = nil) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try database.write { db in
                if var category = editing {
                    category.name = clean
                    try category.update(db)
                } else {
                    let next = (try Category.fetchAll(db).map(\.order).max() ?? -1) + 1
                    try Category(id: UUID(), name: clean, order: next).insert(db)
                }
            }
            refresh()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { errorMessage = "Не удалось сохранить категорию: \(error.localizedDescription)" }
    }

    func deleteCategory(_ category: Category) {
        do { try database.write { db in try category.delete(db) }; refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func saveMenuItem(name: String, price: Double, categoryID: UUID, editing: MenuItem? = nil) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, price > 0 else { return }
        do {
            try database.write { db in
                if var item = editing {
                    item.name = clean; item.price = price; item.categoryId = categoryID
                    try item.update(db)
                } else {
                    try MenuItem(id: UUID(), name: clean, price: price, categoryId: categoryID).insert(db)
                }
            }
            refresh()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { errorMessage = "Не удалось сохранить блюдо: \(error.localizedDescription)" }
    }

    func deleteMenuItem(_ item: MenuItem) {
        do { try database.write { db in try item.delete(db) }; refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func addScannedItems(_ items: [ParsedMenuItem]) {
        do {
            try database.write { db in
                var categoryMap = Dictionary(uniqueKeysWithValues: try Category.fetchAll(db).map { ($0.name.lowercased(), $0) })
                var nextOrder = (categoryMap.values.map(\.order).max() ?? -1) + 1
                for parsed in items where parsed.isSelected {
                    let name = parsed.category.trimmingCharacters(in: .whitespacesAndNewlines)
                    let category: Category
                    if let existing = categoryMap[name.lowercased()] { category = existing }
                    else {
                        let created = Category(id: UUID(), name: name.isEmpty ? "Без категории" : name, order: nextOrder)
                        nextOrder += 1
                        try created.insert(db)
                        categoryMap[created.name.lowercased()] = created
                        category = created
                    }
                    try MenuItem(id: UUID(), name: parsed.name, price: parsed.price, categoryId: category.id).insert(db)
                }
            }
            refresh()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { errorMessage = "Не удалось добавить распознанные блюда: \(error.localizedDescription)" }
    }

    func exportMenu(format: String) throws -> URL {
        let output: Data
        let filename: String
        if format == "json" {
            let records = menuItems.map { item in
                ["name": item.name, "price": item.price, "category": categories.first(where: { $0.id == item.categoryId })?.name ?? ""] as [String: Any]
            }
            output = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            filename = "Меню-OffikHoll.json"
        } else {
            let rows = ["Название;Цена;Категория"] + menuItems.map { item in
                let category = categories.first(where: { $0.id == item.categoryId })?.name ?? ""
                return "\(csv(item.name));\(item.price);\(csv(category))"
            }
            output = ("\u{FEFF}" + rows.joined(separator: "\n")).data(using: .utf8) ?? Data()
            filename = "Меню-OffikHoll.csv"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try output.write(to: url, options: .atomic)
        return url
    }

    private func csv(_ value: String) -> String { "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" }
}
