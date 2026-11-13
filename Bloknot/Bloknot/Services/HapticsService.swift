import Foundation
import UIKit

/// Тактильный отклик. Все вызовы безопасны на симуляторе.
enum HapticsService {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    static func tap() {
        impactLight.impactOccurred()
    }

    static func addDish() {
        impactMedium.impactOccurred()
    }

    static func selection() {
        selectionGenerator.selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
