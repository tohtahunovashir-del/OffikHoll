import SwiftUI

struct CategoryRailButton: View {
    let category: Category
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 22)
                Text(category.name)
                    .font(.system(size: 9.5, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(height: 25)
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isSelected ? Color.white.opacity(0.75) : Palette.inkTertiary)
            }
            .foregroundColor(isSelected ? .white : Palette.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Palette.accentFill : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.name), \(count) блюд")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct DishCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DishCard: View {
    let item: MenuItem
    let quantity: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if quantity > 0 {
                        Text("\(quantity)")
                            .font(Typeface.number(10.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 21, minHeight: 21)
                            .background(Circle().fill(Palette.accentFill))
                    }
                }

                if !item.details.isEmpty {
                    Text(item.details)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.inkTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 4) {
                    Text(Price.string(item.price))
                        .font(Typeface.number(14.5, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    if item.isAvailable {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Palette.accent)
                    } else {
                        Text("СТОП")
                            .font(.system(size: 8.5, weight: .bold))
                            .kerning(0.6)
                            .foregroundColor(Palette.danger)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Palette.dangerSoft))
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(color: Palette.shadow.opacity(0.04), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        quantity > 0 ? Palette.accent.opacity(0.5) : Palette.stroke,
                        lineWidth: quantity > 0 ? 1.5 : 1
                    )
            )
            .opacity(item.isAvailable ? 1 : 0.55)
        }
        .buttonStyle(DishCardButtonStyle())
        .disabled(!item.isAvailable)
        .accessibilityLabel("\(item.name), \(Price.string(item.price))")
    }
}

struct OrderSummaryBar: View {
    @ObservedObject var store: OrderStore
    let onOpen: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            onOpen()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                    Image(systemName: "list.bullet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.itemCount > 0 ? "Текущий заказ" : "Заказ пуст")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))
                    Text("\(AppFormat.items(store.itemCount)) · \(Price.string(store.total))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 4)

                if store.hasUnsentItems {
                    Text("\(store.unsentCount)")
                        .font(Typeface.number(11, weight: .bold))
                        .foregroundColor(Palette.accentFill)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Circle().fill(Palette.gold))
                }

                HStack(spacing: 5) {
                    Text("Открыть")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.accentFill)
                    .shadow(color: Palette.accentFill.opacity(0.32), radius: 14, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .padding(.top, 6)
    }
}

struct OrderLineRow: View {
    let line: OrderLine
    let isLocked: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                Text(line.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Text(Price.string(line.lineTotal))
                    .font(Typeface.number(14.5, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Text("\(Price.string(line.price, showCurrency: false)) × \(line.quantity)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.inkTertiary)

                if line.isSent {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("на кухне")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(Palette.accent)
                }

                Spacer(minLength: 0)

                if !isLocked {
                    QuantityStepper(
                        quantity: line.quantity,
                        compact: true,
                        onDecrease: onDecrease,
                        onIncrease: onIncrease
                    )
                } else {
                    Text("× \(line.quantity)")
                        .font(Typeface.number(12, weight: .semibold))
                        .foregroundColor(Palette.inkSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .contextMenu {
            if !isLocked {
                Button(role: .destructive, action: onRemove) {
                    Label("Удалить позицию", systemImage: "trash")
                }
            }
        }
    }
}
