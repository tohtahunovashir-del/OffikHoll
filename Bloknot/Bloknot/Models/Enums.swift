import Foundation
import GRDB
import SwiftUI

/// Состояние стола на карте зала. Вычисляется из открытого заказа, а не хранится.
enum TableStatus: String, Codable, CaseIterable, Hashable, DatabaseValueConvertible {
    case free
    case active
    case kitchen

    var title: String {
        switch self {
        case .free: return "Свободен"
        case .active: return "Новый заказ"
        case .kitchen: return "На кухне"
        }
    }

    var color: Color {
        switch self {
        case .free: return Theme.green
        case .active: return Theme.yellow
        case .kitchen: return Theme.red
        }
    }
}

/// Жизненный цикл заказа.
enum OrderStatus: String, Codable, CaseIterable, Hashable, DatabaseValueConvertible {
    case open
    case sent
    case paid

    var title: String {
        switch self {
        case .open: return "Новый"
        case .sent: return "На кухне"
        case .paid: return "Оплачен"
        }
    }

    var color: Color {
        switch self {
        case .open: return Theme.yellow
        case .sent: return Theme.red
        case .paid: return Theme.green
        }
    }
}
