import SwiftUI

struct TableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct TableCardView: View {
    let card: FloorCard

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("СТОЛ")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(Palette.inkTertiary)
                    Text("\(card.table.number)")
                        .font(Typeface.display(34, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                StatusPill(
                    text: card.isOccupied ? (card.status?.title ?? "Занят") : "Свободен",
                    color: card.isOccupied ? (card.status?.color ?? Palette.gold) : Palette.accent
                )
            }

            DividerLine()
                .opacity(0.65)

            if card.isOccupied {
                VStack(alignment: .leading, spacing: 3) {
                    if card.previewLines.isEmpty {
                        Text("Заказ открыт")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Palette.inkSecondary)
                    } else {
                        ForEach(Array(card.previewLines.prefix(2).indices), id: \.self) { index in
                            Text(card.previewLines[index])
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(Palette.inkSecondary)
                                .lineLimit(1)
                        }
                        if card.previewLines.count > 2 {
                            Text("и ещё позиции...")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Palette.inkTertiary)
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    MetaLabel(icon: "person.2.fill", text: "\(card.guests)")
                    Spacer(minLength: 4)
                    Text(Price.string(card.total))
                        .font(Typeface.number(16, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                HStack(spacing: 6) {
                    MetaLabel(icon: "clock", text: AppFormat.time(card.openedAt))
                    Text("·")
                        .foregroundColor(Palette.inkTertiary)
                    Text(AppFormat.items(card.itemCount))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Palette.inkTertiary)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(AppFormat.guests(card.table.seats))
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundColor(Palette.inkSecondary)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text(card.table.zone)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Palette.inkTertiary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("Открыть")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Palette.accent)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 174, maxHeight: 174, alignment: .topLeading)
        .background(
            shape
                .fill(
                    LinearGradient(
                        colors: card.isOccupied
                            ? [Palette.surfaceElevated, Palette.gold.opacity(0.09)]
                            : [Palette.surface, Palette.surfaceMuted.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: Palette.shadow.opacity(card.isOccupied ? 0.09 : 0.05),
                    radius: 12,
                    x: 0,
                    y: 7
                )
        )
        .overlay(
            shape.strokeBorder(
                card.isOccupied ? Palette.gold.opacity(0.42) : Palette.stroke,
                lineWidth: 1
            )
        )
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if card.isOccupied {
            return "Стол \(card.table.number), занят, \(Price.string(card.total))"
        }
        return "Стол \(card.table.number), свободен, \(card.table.zone)"
    }
}
