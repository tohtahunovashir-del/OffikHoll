import Combine
import Foundation
import GRDB

/// Сводка по столу для карты зала: статус, сумма и число позиций.
struct TableSummary: Identifiable, Hashable {
    var table: DiningTable
    var orderId: UUID?
    var total: Double
    var itemCount: Int
    var status: TableStatus

    var id: Int64 { table.id }
}

final class TableRepository {
    private let database: DatabaseQueue

    init(database: DatabaseQueue) {
        self.database = database
    }

    func observeSummaries() -> AnyPublisher<[TableSummary], Error> {
        ValueObservation
            .tracking { db -> [TableSummary] in
                let tables = try DiningTable.order(DiningTable.Columns.number).fetchAll(db)
                let orders = try Order
                    .filter(Column("status") != OrderStatus.paid.rawValue)
                    .fetchAll(db)
                let items = try OrderItem.fetchAll(db)

                var totals: [UUID: Double] = [:]
                var counts: [UUID: Int] = [:]
                var hasUnsent: [UUID: Bool] = [:]

                for item in items {
                    totals[item.orderId, default: 0] += item.total
                    counts[item.orderId, default: 0] += item.quantity
                    if !item.isSent {
                        hasUnsent[item.orderId] = true
                    }
                }

                var ordersByTable: [Int64: [Order]] = [:]
                for order in orders {
                    ordersByTable[order.tableId, default: []].append(order)
                }

                return tables.map { table -> TableSummary in
                    let latest = ordersByTable[table.id]?
                        .sorted { $0.createdAt > $1.createdAt }
                        .first

                    guard let order = latest else {
                        return TableSummary(
                            table: table,
                            orderId: nil,
                            total: 0,
                            itemCount: 0,
                            status: .free
                        )
                    }

                    let status: TableStatus = hasUnsent[order.id] == true ? .active : .kitchen
                    return TableSummary(
                        table: table,
                        orderId: order.id,
                        total: totals[order.id] ?? 0,
                        itemCount: counts[order.id] ?? 0,
                        status: status
                    )
                }
            }
            .publisher(in: database)
            .eraseToAnyPublisher()
    }
}
