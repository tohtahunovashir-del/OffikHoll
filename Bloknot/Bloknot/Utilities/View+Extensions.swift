import Foundation
import SwiftUI

/// Единый стиль карточек: радиус 16, мягкая тень.
struct CardModifier: ViewModifier {
    var padding: CGFloat
    var background: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                    .fill(background)
            )
            .shadow(
                color: Color.black.opacity(Constants.cardShadowOpacity),
                radius: Constants.cardShadowRadius,
                x: 0,
                y: Constants.cardShadowY
            )
    }
}

/// Основная кнопка: минимум 50 pt по высоте, скругление 12 pt.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(filled ? .white : tint)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.minButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled ? tint : tint.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(padding: CGFloat = Constants.screenPadding, background: Color = Theme.card) -> some View {
        modifier(CardModifier(padding: padding, background: background))
    }

    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}
