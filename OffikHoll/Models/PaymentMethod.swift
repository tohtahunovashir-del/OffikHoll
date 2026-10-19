import Foundation

enum PaymentMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case cash
    case card
    case transfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return "Наличные"
        case .card: return "Карта"
        case .transfer: return "Перевод"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
    }
}
