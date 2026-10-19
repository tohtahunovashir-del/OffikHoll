import SwiftUI

private func uiColor(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        })
    }
}

enum Palette {
    static let background = Color.adaptive(light: 0xF5F2EA, dark: 0x0A0E0C)
    static let backgroundSecondary = Color.adaptive(light: 0xEDE8DD, dark: 0x0F1411)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x151C19)
    static let surfaceElevated = Color.adaptive(light: 0xFFFFFF, dark: 0x1B2320)
    static let surfaceMuted = Color.adaptive(light: 0xF0ECE3, dark: 0x111815)

    static let ink = Color.adaptive(light: 0x14181A, dark: 0xF4F2EC)
    static let inkSecondary = Color.adaptive(light: 0x5E6662, dark: 0x9DA8A3)
    static let inkTertiary = Color.adaptive(light: 0x8B938E, dark: 0x6B7671)

    static let stroke = Color.adaptive(light: 0xE5DED2, dark: 0x24312C)
    static let strokeStrong = Color.adaptive(light: 0xD3C9B9, dark: 0x34443D)

    static let accent = Color.adaptive(light: 0x0E7C5A, dark: 0x4AD9A8)
    static let accentFill = Color.adaptive(light: 0x0E7C5A, dark: 0x17866A)
    static let accentSoft = Color.adaptive(light: 0xE3F1EA, dark: 0x12271F)

    static let gold = Color.adaptive(light: 0xA9823F, dark: 0xD9B878)
    static let goldSoft = Color.adaptive(light: 0xF4EBD8, dark: 0x2A2317)

    static let danger = Color.adaptive(light: 0xB43A2E, dark: 0xFF7B6E)
    static let dangerSoft = Color.adaptive(light: 0xF8E5E2, dark: 0x2B1815)

    static let paid = Color.adaptive(light: 0x6B7A74, dark: 0x83918B)
    static let shadow = Color.adaptive(light: 0x2A241C, dark: 0x000000)
}

/// Full-screen warm background with two very subtle light sources.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Palette.background
            RadialGradient(
                colors: [Palette.gold.opacity(0.12), Color.clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 480
            )
            RadialGradient(
                colors: [Palette.accent.opacity(0.08), Color.clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

enum Typeface {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
