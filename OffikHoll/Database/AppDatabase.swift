import Foundation
import GRDB

enum DatabaseBootError: LocalizedError {
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return "Не удалось открыть локальную базу данных."
        }
    }
}

/// Owns the SQLite queue. The app is 100% offline: GRDB is the single source
/// of truth and every screen is driven by `ValueObservation`.
enum AppDatabase {
    static func makeQueue() throws -> DatabaseQueue {
        let fileManager = FileManager.default
        guard let support = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            throw DatabaseBootError.storageUnavailable
        }
        let folder = support.appendingPathComponent("OffikHoll", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("offikholl.sqlite")
        let queue = try DatabaseQueue(path: url.path)
        try migrate(queue)
        return queue
    }

    static func makeInMemoryQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        try migrate(queue)
        return queue
    }

    private static func migrate(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_schema") { db in
            try db.execute(sql: """
                CREATE TABLE categories (
                    id BLOB PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    sortOrder INTEGER NOT NULL DEFAULT 0,
                    icon TEXT NOT NULL DEFAULT 'fork.knife'
                );

                CREATE TABLE menu_items (
                    id BLOB PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    price DOUBLE NOT NULL,
                    categoryId BLOB NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
                    details TEXT NOT NULL DEFAULT '',
                    isAvailable BOOLEAN NOT NULL DEFAULT 1,
                    createdAt DATETIME NOT NULL
                );

                CREATE INDEX idx_menu_items_category ON menu_items(categoryId);
                CREATE INDEX idx_menu_items_name ON menu_items(name);

                CREATE TABLE tables (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    number INTEGER NOT NULL,
                    status TEXT NOT NULL DEFAULT 'free',
                    currentOrderId BLOB,
                    zone TEXT NOT NULL DEFAULT 'Основной зал',
                    seats INTEGER NOT NULL DEFAULT 2
                );

                CREATE UNIQUE INDEX idx_tables_number ON tables(number);

                CREATE TABLE orders (
                    id BLOB PRIMARY KEY NOT NULL,
                    tableId INTEGER NOT NULL REFERENCES tables(id) ON DELETE CASCADE,
                    status TEXT NOT NULL DEFAULT 'active',
                    totalAmount DOUBLE NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL,
                    sentAt DATETIME,
                    closedAt DATETIME,
                    guests INTEGER NOT NULL DEFAULT 2,
                    note TEXT NOT NULL DEFAULT '',
                    paymentMethod TEXT
                );

                CREATE INDEX idx_orders_status ON orders(status);
                CREATE INDEX idx_orders_table ON orders(tableId);
                CREATE INDEX idx_orders_closedAt ON orders(closedAt);

                CREATE TABLE order_items (
                    id BLOB PRIMARY KEY NOT NULL,
                    orderId BLOB NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
                    menuItemId BLOB NOT NULL,
                    quantity INTEGER NOT NULL DEFAULT 1,
                    nameSnapshot TEXT NOT NULL DEFAULT '',
                    priceSnapshot DOUBLE NOT NULL DEFAULT 0,
                    isSent BOOLEAN NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL
                );

                CREATE INDEX idx_order_items_order ON order_items(orderId);
                CREATE INDEX idx_order_items_menu ON order_items(menuItemId);
                """)
        }

        migrator.registerMigration("v2_seed_demo_content") { db in
            let categoryCount = try Category.fetchCount(db)
            guard categoryCount == 0 else { return }
            try seed(db)
        }

        try migrator.migrate(queue)
    }

    // MARK: - Demo content

    private struct SeedItem {
        let name: String
        let price: Double
        let details: String
    }

    private struct SeedCategory {
        let name: String
        let icon: String
        let items: [SeedItem]
    }

    private static func seed(_ db: Database) throws {
        let categories: [SeedCategory] = [
            SeedCategory(name: "Завтраки", icon: "sun.max.fill", items: [
                SeedItem(name: "Сырники из фермерского творога", price: 390, details: "180 г · сметана и малиновый соус"),
                SeedItem(name: "Овсяная каша с карамелизированной грушей", price: 320, details: "250 г"),
                SeedItem(name: "Яйца Бенедикт с лососем", price: 590, details: "220 г"),
                SeedItem(name: "Омлет с томатами и страчателлой", price: 450, details: "200 г"),
                SeedItem(name: "Круассан с миндальным кремом", price: 280, details: "120 г"),
                SeedItem(name: "Авокадо-тост с яйцом пашот", price: 480, details: "210 г")
            ]),
            SeedCategory(name: "Салаты", icon: "leaf.fill", items: [
                SeedItem(name: "Цезарь с курицей", price: 520, details: "230 г"),
                SeedItem(name: "Салат с томатами и бурратой", price: 640, details: "210 г"),
                SeedItem(name: "Тёплый салат с уткой", price: 720, details: "240 г"),
                SeedItem(name: "Греческий салат", price: 460, details: "220 г"),
                SeedItem(name: "Салат с тунцом и кунжутом", price: 610, details: "200 г")
            ]),
            SeedCategory(name: "Супы", icon: "cup.and.saucer.fill", items: [
                SeedItem(name: "Борщ с говядиной и сметаной", price: 420, details: "350 мл"),
                SeedItem(name: "Крем-суп из тыквы", price: 380, details: "300 мл · тыквенные семечки"),
                SeedItem(name: "Том-ям с креветками", price: 590, details: "350 мл"),
                SeedItem(name: "Куриный бульон с домашней лапшой", price: 350, details: "350 мл"),
                SeedItem(name: "Гаспачо с базиликовым маслом", price: 390, details: "300 мл")
            ]),
            SeedCategory(name: "Горячее", icon: "fork.knife", items: [
                SeedItem(name: "Куриная грудка с картофельным пюре", price: 590, details: "280 г"),
                SeedItem(name: "Треска с овощами и соусом бер-блан", price: 690, details: "260 г"),
                SeedItem(name: "Ризотто с белыми грибами", price: 650, details: "280 г"),
                SeedItem(name: "Пельмени сибирские со сметаной", price: 480, details: "250 г"),
                SeedItem(name: "Котлета по-киевски", price: 620, details: "240 г")
            ]),
            SeedCategory(name: "Гриль", icon: "flame.fill", items: [
                SeedItem(name: "Стейк рибай", price: 1890, details: "320 г"),
                SeedItem(name: "Стейк нью-йорк", price: 1690, details: "300 г"),
                SeedItem(name: "Шашлык из телятины", price: 890, details: "320 г"),
                SeedItem(name: "Овощи на гриле", price: 390, details: "250 г"),
                SeedItem(name: "Куриный шашлык", price: 620, details: "280 г")
            ]),
            SeedCategory(name: "Паста и пицца", icon: "circle.grid.3x3.fill", items: [
                SeedItem(name: "Паста карбонара", price: 590, details: "280 г"),
                SeedItem(name: "Тальятелле с трюфельным соусом", price: 850, details: "270 г"),
                SeedItem(name: "Пицца Маргарита", price: 620, details: "32 см"),
                SeedItem(name: "Пицца Пепперони", price: 720, details: "32 см"),
                SeedItem(name: "Пицца с прошутто и рукколой", price: 780, details: "32 см")
            ]),
            SeedCategory(name: "Десерты", icon: "heart.fill", items: [
                SeedItem(name: "Тирамису", price: 420, details: "120 г"),
                SeedItem(name: "Чизкейк с малиновым соусом", price: 390, details: "140 г"),
                SeedItem(name: "Шоколадный фондан с мороженым", price: 450, details: "160 г"),
                SeedItem(name: "Медовик", price: 340, details: "150 г"),
                SeedItem(name: "Панна-котта с ягодным компоте", price: 380, details: "130 г")
            ]),
            SeedCategory(name: "Напитки", icon: "drop.fill", items: [
                SeedItem(name: "Эспрессо", price: 190, details: "40 мл"),
                SeedItem(name: "Капучино", price: 290, details: "200 мл"),
                SeedItem(name: "Латте", price: 310, details: "300 мл"),
                SeedItem(name: "Свежевыжатый апельсиновый сок", price: 350, details: "250 мл"),
                SeedItem(name: "Домашний морс", price: 250, details: "300 мл"),
                SeedItem(name: "Чай с чабрецом", price: 220, details: "400 мл"),
                SeedItem(name: "Лимонад «Огурец-базилик»", price: 320, details: "350 мл")
            ])
        ]

        var categoryIndex = 0
        for seedCategory in categories {
            let category = Category(
                name: seedCategory.name,
                order: categoryIndex,
                icon: seedCategory.icon
            )
            try category.insert(db)
            for seedItem in seedCategory.items {
                let item = MenuItem(
                    name: seedItem.name,
                    price: seedItem.price,
                    categoryId: category.id,
                    details: seedItem.details
                )
                try item.insert(db)
            }
            categoryIndex += 1
        }

        let zones: [(String, Int, Int)] = [
            ("Основной зал", 1, 2),
            ("Основной зал", 2, 4),
            ("Основной зал", 3, 2),
            ("Основной зал", 4, 6),
            ("Основной зал", 5, 4),
            ("Основной зал", 6, 2),
            ("Основной зал", 7, 4),
            ("Основной зал", 8, 8),
            ("Терраса", 9, 4),
            ("Терраса", 10, 2),
            ("Терраса", 11, 6),
            ("Терраса", 12, 4),
            ("Бар", 13, 2),
            ("Бар", 14, 2)
        ]
        for (index, zone) in zones.enumerated() {
            let table = RestaurantTable(
                id: index + 1,
                number: zone.1,
                zone: zone.0,
                seats: zone.2
            )
            try table.insert(db)
        }
    }
}
