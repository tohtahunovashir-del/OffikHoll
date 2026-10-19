import SwiftUI

struct OrderDetailView: View {
    @ObservedObject var store: OrderStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                SheetHandle()
                header
                ScrollView(showsIndicators: false) {
                    OrderDetailBody(store: store)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                }
                OrderActionBar(store: store) {
                    dismiss()
                }
            }
        }
        .errorAlert($store.errorMessage)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("СТОЛ \(store.tableNumber)")
                    .font(.system(size: 9.5, weight: .semibold))
                    .kerning(1.4)
                    .foregroundColor(Palette.gold)
                Text("Заказ")
                    .font(Typeface.display(29, weight: .semibold))
                    .foregroundColor(Palette.ink)
                HStack(spacing: 8) {
                    StatusPill(text: store.status.title, color: store.status.color)
                    MetaLabel(icon: "person.2.fill", text: "\(store.guests)")
                    Text("·")
                        .foregroundColor(Palette.inkTertiary)
                    Text(AppFormat.items(store.itemCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.inkSecondary)
                }
            }
            Spacer(minLength: 6)
            CircleIconButton(icon: "xmark", accessibilityTitle: "Закрыть") {
                dismiss()
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

/// Third column on iPad and landscape.
struct OrderDetailEmbedded: View {
    @ObservedObject var store: OrderStore
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ТЕКУЩИЙ ЗАКАЗ")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(1.3)
                        .foregroundColor(Palette.gold)
                    Text("Стол \(store.tableNumber)")
                        .font(Typeface.display(23, weight: .semibold))
                        .foregroundColor(Palette.ink)
                }
                Spacer(minLength: 4)
                StatusPill(text: store.status.title, color: store.status.color)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 9)

            Rectangle()
                .fill(Palette.stroke)
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                OrderDetailBody(store: store)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            }

            OrderActionBar(store: store, onDone: onDone)
        }
        .background(Palette.backgroundSecondary.opacity(0.55))
    }
}

struct OrderDetailBody: View {
    @ObservedObject var store: OrderStore
    @State private var noteDraft = ""
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.isPaid {
                paidBanner
            }
            linesSection
            noteSection
            totalsSection
        }
        .onAppear {
            noteDraft = store.note
        }
        .onChange(of: store.note) { newNote in
            if !noteFocused { noteDraft = newNote }
        }
        .onChange(of: noteFocused) { focused in
            if !focused { store.updateNote(noteDraft) }
        }
    }

    private var paidBanner: some View {
        HStack(spacing: 12) {
            IconBadge(icon: "checkmark.seal.fill", tint: Palette.accent, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Заказ оплачен")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Text("\(Price.string(store.order?.totalAmount ?? store.total))\(store.paymentMethodTitle.map { " · \($0)" } ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Palette.inkSecondary)
            }
            Spacer()
        }
        .premiumCard(padding: 14, cornerRadius: 18)
    }

    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Состав заказа")
                Spacer()
                if store.hasUnsentItems {
                    Text("не отправлено: \(store.unsentCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Palette.gold)
                }
            }

            if store.lines.isEmpty {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "Заказ пока пуст",
                    message: "Нажмите на блюдо в меню — оно сразу появится в заказе."
                )
                .premiumCard(padding: 4, cornerRadius: 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.lines.indices), id: \.self) { index in
                        let line = store.lines[index]
                        OrderLineRow(
                            line: line,
                            isLocked: store.isPaid,
                            onDecrease: { store.decrement(lineId: line.id) },
                            onIncrease: { store.increment(lineId: line.id) },
                            onRemove: { store.remove(lineId: line.id) }
                        )
                        if index < store.lines.count - 1 {
                            Rectangle()
                                .fill(Palette.stroke)
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Комментарий к заказу")
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.inkTertiary)
                    .padding(.top, 2)
                TextField("Например: подать позже", text: $noteDraft, axis: .vertical)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1...3)
                    .focused($noteFocused)
                    .submitLabel(.done)
                    .disabled(store.isPaid)
                    .onSubmit {
                        store.updateNote(noteDraft)
                        noteFocused = false
                    }
                if noteDraft != store.note && !store.isPaid {
                    Button("Сохранить") {
                        store.updateNote(noteDraft)
                        noteFocused = false
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
    }

    private var totalsSection: some View {
        VStack(spacing: 9) {
            totalRow("Позиции", "\(store.itemCount)")
            totalRow("Гостей", "\(store.guests)")
            totalRow("На кухне", "\(store.lines.filter(\.isSent).count) из \(store.lines.count)")
            Rectangle()
                .fill(Palette.stroke)
                .frame(height: 1)
                .padding(.vertical, 3)
            HStack(alignment: .firstTextBaseline) {
                Text("Итого")
                    .font(Typeface.display(19, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text(Price.string(store.isPaid ? (store.order?.totalAmount ?? store.total) : store.total))
                    .font(Typeface.number(24, weight: .bold))
                    .foregroundColor(Palette.ink)
            }
        }
        .premiumCard(padding: 15, cornerRadius: 20)
    }

    private func totalRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Palette.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Palette.ink)
        }
    }
}

struct OrderActionBar: View {
    @ObservedObject var store: OrderStore
    var onDone: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showPayment = false
    @State private var showCloseConfirm = false

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Palette.stroke)
                .frame(height: 1)

            if store.isPaid {
                Button {
                    if let onDone { onDone() } else { dismiss() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                        Text("Готово")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    if store.sendToKitchen() {
                        Haptics.success()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                        Text(store.hasUnsentItems
                             ? "На кухню · \(store.unsentCount)"
                             : "Всё отправлено")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(!store.hasUnsentItems || store.lines.isEmpty)
                .opacity((!store.hasUnsentItems || store.lines.isEmpty) ? 0.55 : 1)

                Button {
                    showPayment = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                        Text("Оплата · \(Price.string(store.total))")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(store.lines.isEmpty)
                .opacity(store.lines.isEmpty ? 0.55 : 1)

                Button("Закрыть заказ") {
                    showCloseConfirm = true
                }
                .buttonStyle(DestructiveButtonStyle(compact: true))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Palette.background)
        .sheet(isPresented: $showPayment) {
            PaymentSheet(store: store)
                .presentationDetents([.fraction(0.82), .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Закрыть заказ?",
            isPresented: $showCloseConfirm,
            titleVisibility: .visible
        ) {
            Button("Закрыть без оплаты", role: .destructive) {
                if store.cancelOrder() {
                    Haptics.warning()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Заказ будет удалён, стол освободится. Действие нельзя отменить.")
        }
    }
}
