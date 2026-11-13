import CoreGraphics
import Foundation

enum Constants {
    // Лейаут
    static let screenPadding: CGFloat = 16
    static let spacing: CGFloat = 16
    static let sidebarWidth: CGFloat = 140
    static let bottomBarHeight: CGFloat = 80
    static let cornerRadius: CGFloat = 16
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2
    static let cardShadowOpacity: Double = 0.08

    // Сетки
    static let tableColumns = 3
    static let dishColumns = 2

    // Тач-таргеты
    static let minButtonHeight: CGFloat = 50
    static let minTouchSize: CGFloat = 44

    // Тексты
    static let appName = "Bloknot"
    static let defaultVenueName = "Bloknot"
    static let defaultCategoryName = "Разное"
    static let venueNameKey = "venueName"

    // Настройки OCR
    static let ocrMaxDimension: CGFloat = 2048
    static let ocrMinimumPrice: Double = 10
    static let ocrMaximumPrice: Double = 100_000
}
