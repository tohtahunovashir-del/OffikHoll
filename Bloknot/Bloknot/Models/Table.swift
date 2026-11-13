import Foundation
import GRDB

/// Стол в зале.
///
/// Тип назван `DiningTable`, а не `Table`, чтобы не конфликтовать с `SwiftUI.Table`
/// (доступен начиная с iOS 16) — иначе компилятор не сможет выбрать между ними.
struct DiningTable: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "tables"

    var id: Int64
    var number: Int
    var zone: String
    var seats: Int

    enum Columns {
        static let id = Column("id")
        static let number = Column("number")
        static let zone = Column("zone")
        static let seats = Column("seats")
    }

    init(id: Int64 = 0, number: Int, zone: String, seats: Int) {
        self.id = id
        self.number = number
        self.zone = zone
        self.seats = seats
    }

    /// `id == 0` означает «новая запись»: колонку не пишем и позволяем
    /// SQLite выдать rowid. Иначе все столы из сида получили бы id 0
    /// и упёрлись в UNIQUE-индекс.
    func encode(to container: inout PersistenceContainer) {
        if id != 0 {
            container[Columns.id] = id
        }
        container[Columns.number] = number
        container[Columns.zone] = zone
        container[Columns.seats] = seats
    }
}
