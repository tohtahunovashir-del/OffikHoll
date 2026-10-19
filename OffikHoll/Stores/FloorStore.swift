import Foundation
import GRDB
import Combine

/// Reactive floor state: tables, open bills, revenue. One observation feeds
/// the whole floor screen, the orders screen and the settings table manager.
final class FloorStore: ObservableObject {
    @Published private(set) var cards: [FloorCard] = []
    @Published private(set) var stats: FloorStats = .empty
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let database: DatabaseQueue
    private var observationCancellable = Set<AnyCancellable>()

    init(database: DatabaseQueue) {
        self.database = database
        observe()
    }

    private func observe() {
        ValueObservation
            .tracking { db -> FloorSnapshot in
                let paid = OrderStatus.paid.rawValue
                let tables = try RestaurantTable
                    .order(RestaurantTable.Columns.number)
                    .fetchAll(db)
                let openOrders = try Order
                    .filter(Order.Columns.status != paid)
                    .order(Order.Columns.createdAt)
                    .fetchAll(db)

                let startOfDay = Calendar.current.startOfDay(for: Date())
                let revenueToday = try Double.fetchOne(
                    db,
                    sql: "SELECT COALESCE(SUM(totalAmount), 0) FROM orders WHERE status = ? AND closedAt >= ?",
                    arguments: [paid, startOfDay]
                ) ?? 0
                let paidOrdersToday = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM orders WHERE status = ? AND closedAt >= ?",
                    arguments: [paid, startOfDay]
                ) ?? 0

                let previewRows = try Row.fetchAll(db, sql: """
                    SELECT oi.orderId AS orderId,
                           oi.nameSnapshot AS name,
                           oi.quantity AS quantity
                    FROM order_items oi
                    JOIN orders o ON o.id = oi.orderId
                    WHERE o.status <> ?
                    ORDER BY oi.createdAt ASC
                    """, arguments: [paid])
                var previewNames: [UUID: [String]] = [:]
                var itemCounts: [UUID: Int] = [:]
                for row in previewRows {
                    let orderId: UUID = row["orderId"]
                    let name: String = row["name"]
                    let quantity: Int = row["quantity"]
                    let label = quantity > 1 ? "\(quantity) × \(name)" : name
                    previewNames[orderId, default: []].append(label)
                    itemCounts[orderId, default: 0] += quantity
                }

                let totalRows = try Row.fetchAll(db, sql: """
                    SELECT orderId AS orderId,
                           COALESCE(SUM(priceSnapshot * quantity), 0) AS total
                    FROM order_items
                    GROUP BY orderId
                    """)
                var totals: [UUID: Double] = [:]
                for row in totalRows {
                    let orderId: UUID = row["orderId"]
                    let total: Double = row["total"]
                    totals[orderId] = total
                }

                let cards: [FloorCard] = tables.map { table in
                    let order = openOrders.first(where: { $0.tableId == table.id })
                    let previews = order.flatMap { previewNames[$0.id] } ?? []
                    return FloorCard(
                        table: table,
                        order: order,
                        previewLines: Array(previews.prefix(3)),
                        itemCount: order.flatMap { itemCounts[$0.id] } ?? 0,
                        total: order.flatMap { totals[$0.id] } ?? 0,
                        guests: order?.guests ?? 0,
                        openedAt: order?.createdAt
                    )
                }

                let occupiedCards = cards.filter(\.isOccupied)
                let openTotal = openOrders.reduce(0.0) { partial, order in
                    partial + (totals[order.id] ?? order.totalAmount)
                }
                let stats = FloorStats(
                    freeTables: cards.count - occupiedCards.count,
                    occupiedTables: occupiedCards.count,
                    openOrders: openOrders.count,
                    openTotal: openTotal,
                    revenueToday: revenueToday,
                    guests: openOrders.reduce(0) { $0 + $1.guests },
                    paidOrdersToday: paidOrdersToday
                )
                return FloorSnapshot(cards: cards, stats: stats)
            }
            .publisher(in: database)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = "Не удалось прочитать зал: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] snapshot in
                self?.cards = snapshot.cards
                self?.stats = snapshot.stats
                self?.isLoading = false
            })
            .store(in: &observationCancellable)
    }

    // MARK: - Derived data

    var tables: [RestaurantTable] {
        cards.map(\.table)
    }

    var zones: [String] {
        var result: [String] = []
        for card in cards where !result.contains(card.table.zone) {
            result.append(card.table.zone)
        }
        return result
    }

    var openCards: [FloorCard] {
        cards.filter(\.isOccupied)
    }

    var newOrderCards: [FloorCard] {
        openCards.filter { $0.status == .active }
    }

    var sentOrderCards: [FloorCard] {
        openCards.filter { $0.status == .sent }
    }

    func card(for tableId: Int) -> FloorCard? {
        cards.first(where: { $0.table.id == tableId })
    }

    func cards(in zone: String?) -> [FloorCard] {
        guard let zone, zone != "Все столы" else { return cards }
        return cards.filter { $0.table.zone == zone }
    }

    // MARK: - Orders

    /// Returns the id of the open order for the table, creating a new bill on
    /// the first tap. This is iikoWaiter's "tap a table -> take the order"
    /// flow without any extra modal steps.
    func openOrder(for table: RestaurantTable) -> UUID? {
        do {
            return try database.write { db -> UUID in
                if let existing = try Order
                    .filter(Order.Columns.tableId == table.id)
                    .filter(Order.Columns.status != OrderStatus.paid.rawValue)
                    .order(Order.Columns.createdAt.desc)
                    .fetchOne(db) {
                    try db.execute(
                        sql: "UPDATE tables SET status = ?, currentOrderId = ? WHERE id = ?",
                        arguments: [TableStatus.occupied.rawValue, existing.id, table.id]
                    )
                    return existing.id
                }
                let order = Order(
                    tableId: table.id,
                    guests: max(1, min(table.seats, 12))
                )
                try order.insert(db)
                try db.execute(
                    sql: "UPDATE tables SET status = ?, currentOrderId = ? WHERE id = ?",
                    arguments: [TableStatus.occupied.rawValue, order.id, table.id]
                )
                return order.id
            }
        } catch {
            errorMessage = "Не удалось открыть заказ: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Table management

    /// Returns a Russian error message, or nil when the table was saved.
    @discardableResult
    func addTable(number: Int, seats: Int, zone: String) -> String? {
        guard number > 0 else { return "Номер стола должен быть больше нуля." }
        guard seats >= 1, seats <= 30 else { return "Количество мест должно быть от 1 до 30." }
        guard !cards.contains(where: { $0.table.number == number }) else {
            return "Стол № \(number) уже существует."
        }
        let trimmedZone = zone.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try database.write { db in
                let nextId = try Int.fetchOne(
                    db,
                    sql: "SELECT COALESCE(MAX(id), 0) + 1 FROM tables"
                ) ?? 1
                let table = RestaurantTable(
                    id: nextId,
                    number: number,
                    zone: trimmedZone.isEmpty ? "Основной зал" : trimmedZone,
                    seats: seats
                )
                try table.insert(db)
            }
            return nil
        } catch {
            return "Не удалось добавить стол: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func updateTable(_ table: RestaurantTable, number: Int, seats: Int, zone: String) -> String? {
        guard number > 0 else { return "Номер стола должен быть больше нуля." }
        guard seats >= 1, seats <= 30 else { return "Количество мест должно быть от 1 до 30." }
        guard !cards.contains(where: { $0.table.id != table.id && $0.table.number == number }) else {
            return "Стол № \(number) уже существует."
        }
        var updated = table
        updated.number = number
        updated.seats = seats
        let trimmedZone = zone.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.zone = trimmedZone.isEmpty ? "Основной зал" : trimmedZone
        do {
            try database.write { db in
                try updated.update(db)
            }
            return nil
        } catch {
            return "Не удалось сохранить стол: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteTable(_ table: RestaurantTable) -> String? {
        if card(for: table.id)?.isOccupied == true {
            return "Сначала закройте заказ на этом столе."
        }
        do {
            try database.write { db in
                _ = try table.delete(db)
            }
            return nil
        } catch {
            return "Не удалось удалить стол: \(error.localizedDescription)"
        }
    }
}
