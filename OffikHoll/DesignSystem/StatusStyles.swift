import SwiftUI

extension OrderStatus {
    var title: String {
        switch self {
        case .active: return "Новый"
        case .sent: return "На кухне"
        case .paid: return "Оплачен"
        }
    }

    var color: Color {
        switch self {
        case .active: return Palette.gold
        case .sent: return Palette.accent
        case .paid: return Palette.paid
        }
    }

    var icon: String {
        switch self {
        case .active: return "sparkles"
        case .sent: return "flame.fill"
        case .paid: return "checkmark.circle.fill"
        }
    }
}

extension TableStatus {
    var title: String {
        switch self {
        case .free: return "Свободен"
        case .occupied: return "Занят"
        }
    }

    var color: Color {
        switch self {
        case .free: return Palette.accent
        case .occupied: return Palette.gold
        }
    }
}
