import Foundation

enum AppTab: Hashable {
    case floor
    case orders
    case menu
    case settings
}

struct OrderRoute: Hashable {
    let orderId: UUID
}
