import SwiftUI
import UIKit

// MARK: - Headers

struct ScreenHeader<Trailing: View>: View {
    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let trailing: () -> Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10.5, weight: .semibold))
                        .kerning(1.6)
                        .foregroundColor(Palette.gold)
                }
                Text(title)
                    .font(Typeface.display(34, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Palette.inkSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

// MARK: - Cards

struct PremiumCardModifier: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat
    var elevated: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(
                        color: Palette.shadow.opacity(elevated ? 0.10 : 0.05),
                        radius: elevated ? 18 : 10,
                        x: 0,
                        y: elevated ? 10 : 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func premiumCard(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        elevated: Bool = false
    ) -> some View {
        modifier(PremiumCardModifier(padding: padding, cornerRadius: cornerRadius, elevated: elevated))
    }
}

// MARK: - Pills & labels

struct StatusPill: View {
    let text: String
    var color: Color = Palette.accent
    var emphasized: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(emphasized ? color : Palette.inkSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(emphasized ? color.opacity(0.13) : Palette.surfaceMuted)
        )
        .overlay(
            Capsule().strokeBorder(color.opacity(emphasized ? 0.28 : 0), lineWidth: 1)
        )
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .kerning(1.4)
            .foregroundColor(Palette.inkTertiary)
    }
}

struct MetaLabel: View {
    let icon: String
    let text: String
    var tint: Color = Palette.inkSecondary

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(tint)
    }
}

struct IconBadge: View {
    let icon: String
    var tint: Color = Palette.gold
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(tint.opacity(0.14))
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(tint)
        }
        .frame(width: size, height: size)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(height: 1)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.accentFill
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = compact ? 14 : 18
        configuration.label
            .font(.system(size: compact ? 15 : 17, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: compact ? 46 : 54)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.90), tint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.10 : 0.26), radius: 12, x: 0, y: 7)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 17, weight: .semibold))
            .foregroundColor(Palette.ink)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: compact ? 46 : 54)
            .background(
                RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                    .strokeBorder(Palette.strokeStrong, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 16, weight: .semibold))
            .foregroundColor(Palette.danger)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 52)
            .background(
                RoundedRectangle(cornerRadius: compact ? 14 : 17, style: .continuous)
                    .fill(Palette.dangerSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 14 : 17, style: .continuous)
                    .strokeBorder(Palette.danger.opacity(0.25), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct CircleIconButton: View {
    let icon: String
    var accessibilityTitle: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Palette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.surface))
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
    }
}

// MARK: - Chips

struct FilterChip: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? Color.white.opacity(0.22) : Palette.surfaceMuted)
                        )
                }
            }
            .foregroundColor(isSelected ? .white : Palette.inkSecondary)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(
                Capsule().fill(isSelected ? Palette.accentFill : Palette.surface)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : Palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Controls

struct QuantityStepper: View {
    let quantity: Int
    var compact: Bool = false
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    private var controlSize: CGSize {
        compact ? CGSize(width: 34, height: 32) : CGSize(width: 42, height: 40)
    }

    var body: some View {
        HStack(spacing: 2) {
            Button {
                Haptics.selection()
                onDecrease()
            } label: {
                Image(systemName: quantity <= 1 ? "trash" : "minus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: controlSize.width, height: controlSize.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("\(quantity)")
                .font(Typeface.number(compact ? 13 : 15, weight: .semibold))
                .frame(minWidth: 24)

            Button {
                Haptics.impact(.light)
                onIncrease()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: controlSize.width, height: controlSize.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(Palette.ink)
        .background(Capsule().fill(Palette.surfaceMuted))
        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.inkTertiary)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(Palette.ink)
                .submitLabel(.search)
                .autocorrectionDisabled(true)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.inkTertiary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
    }
}

struct StatBlock: View {
    let title: String
    let value: String
    var tint: Color = Palette.ink
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .kerning(1.0)
                .foregroundColor(Palette.inkTertiary)
                .lineLimit(1)
            Text(value)
                .font(Typeface.number(20, weight: .semibold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Sheet chrome & empty state

struct SheetHandle: View {
    var body: some View {
        Capsule()
            .fill(Palette.strokeStrong)
            .frame(width: 38, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Palette.goldSoft)
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(Palette.gold)
            }
            Text(title)
                .font(Typeface.display(21, weight: .semibold))
                .foregroundColor(Palette.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .frame(maxWidth: 280)
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Error alert

struct ErrorAlertModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert(
            "Ошибка",
            isPresented: Binding(
                get: { message != nil },
                set: { isPresented in
                    if !isPresented { message = nil }
                }
            )
        ) {
            Button("Понятно", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

extension View {
    func errorAlert(_ message: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(message: message))
    }
}

// MARK: - Sharing

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
