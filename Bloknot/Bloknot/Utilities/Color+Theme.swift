import Foundation
import SwiftUI

/// Палитра Bloknot. Акцент — тёплый оранжевый #FF6B35.
enum Theme {
    static let accent = Color(hex: 0xFF6B35)
    static let accentSoft = Color(hex: 0xFFF0EA)
    static let accentDeep = Color(hex: 0xE25420)

    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let card = Color(uiColor: .secondarySystemBackground)
    static let elevated = Color(uiColor: .tertiarySystemBackground)

    static let ink = Color.primary
    static let inkSecondary = Color.secondary
    static let inkTertiary = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)

    static let green = Color(hex: 0x2E9E6B)
    static let greenSoft = Color(hex: 0xE7F5EE)
    static let yellow = Color(hex: 0xE8A33D)
    static let yellowSoft = Color(hex: 0xFDF2E2)
    static let red = Color(hex: 0xD9503F)
    static let redSoft = Color(hex: 0xFBEAE7)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
