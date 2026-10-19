import SwiftUI

struct PaymentSheet: View {
    @ObservedObject var store: OrderStore
    @Environment(\.dismiss) private var dismiss
    @State private var method: PaymentMethod = .card
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 16) {
                SheetHandle()

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        SectionLabel(text: "Оплата")
                        Text("Стол \(store.tableNumber)")
                            .font(Typeface.display(26, weight: .semibold))
                            .foregroundColor(Palette.ink)
                    }
                    Spacer()
                    IconBadge(icon: "creditcard.fill", tint: Palette.gold, size: 46)
                }

                VStack(spacing: 1) {
                    Text("К оплате")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Palette.inkSecondary)
                    Text(Price.string(store.total))
                        .font(Typeface.number(38, weight: .bold))
                        .foregroundColor(Palette.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )

                HStack(spacing: 8) {
                    ForEach(PaymentMethod.allCases) { option in
                        methodButton(option)
                    }
                }

                HStack(spacing: 14) {
                    MetaLabel(icon: "list.bullet", text: AppFormat.items(store.itemCount))
                    Spacer(minLength: 0)
                    MetaLabel(icon: "person.2.fill", text: "\(store.guests)")
                    Spacer(minLength: 0)
                    MetaLabel(icon: store.status.icon, text: store.status.title, tint: store.status.color)
                }
                .padding(.horizontal, 2)

                Spacer(minLength: 0)

                Button {
                    pay()
                } label: {
                    Text(isProcessing ? "Проводим оплату..." : "Оплатить \(Price.string(store.total))")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isProcessing || store.lines.isEmpty)

                Button("Отмена") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Palette.inkSecondary)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .errorAlert($store.errorMessage)
    }

    private func methodButton(_ option: PaymentMethod) -> some View {
        Button {
            Haptics.selection()
            method = option
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(option.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .foregroundColor(method == option ? .white : Palette.inkSecondary)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(method == option ? Palette.accentFill : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(method == option ? Color.clear : Palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func pay() {
        isProcessing = true
        let success = store.pay(method: method)
        isProcessing = false
        if success {
            Haptics.success()
            dismiss()
        } else {
            Haptics.error()
        }
    }
}
