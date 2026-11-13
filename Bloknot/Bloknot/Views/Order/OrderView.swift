import Foundation
import SwiftUI

struct OrderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderViewModel
    @State private var isShowingSheet = false

    init(table: DiningTable, orderId: UUID) {
        _viewModel = StateObject(wrappedValue: OrderViewModel(table: table, orderId: orderId))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                CategorySidebar(
                    categories: viewModel.categories,
                    selectedId: viewModel.selectedCategoryId,
                    onSelect: { id in viewModel.select(categoryId: id) }
                )
                .frame(width: Constants.sidebarWidth)

                Divider()

                MenuGrid(
                    items: viewModel.dishes,
                    quantity: { id in viewModel.quantity(for: id) },
                    onTap: { item in viewModel.add(item) }
                )
            }
            .frame(maxHeight: .infinity)

            Divider()

            OrderBottomBar(
                itemCount: viewModel.itemCount,
                total: viewModel.total,
                onTap: { isShowingSheet = true }
            )
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingSheet) {
            OrderSheetView(viewModel: viewModel)
        }
        .onChange(of: viewModel.isClosed) { closed in
            if closed {
                dismiss()
            }
        }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Стол \(viewModel.table.number)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.ink)
                Text("\(viewModel.table.zone) · \(Plural.guests(viewModel.guests))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            statusBadge
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.background)
    }

    private var statusBadge: some View {
        let status = viewModel.snapshot.order?.status ?? .open
        return Text(status.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(status.color.opacity(0.12))
            )
            .padding(.trailing, 8)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }
}

// MARK: - Order sheet

struct OrderSheetView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingCancel = false

    init(viewModel: OrderViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.lines.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.lines) { line in
                            OrderItemRow(
                                line: line,
                                onIncrement: { viewModel.increment(line) },
                                onDecrement: { viewModel.decrement(line) }
                            )
                        }
                        .onDelete { offsets in
                            for index in offsets where index < viewModel.lines.count {
                                viewModel.remove(viewModel.lines[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Счёт · стол \(viewModel.table.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        isConfirmingCancel = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.lines.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .confirmationDialog(
                "Отменить заказ?",
                isPresented: $isConfirmingCancel,
                titleVisibility: .visible
            ) {
                Button("Отменить и освободить стол", role: .destructive) {
                    viewModel.cancelOrder()
                    dismiss()
                }
                Button("Оставить", role: .cancel) {}
            } message: {
                Text("Счёт будет удалён, стол снова станет свободным.")
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: viewModel.isClosed) { closed in
            if closed {
                dismiss()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(Theme.inkTertiary)
            Text("В заказе пока нет позиций")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.ink)
            Text("Нажмите на блюдо, чтобы добавить его в счёт.")
                .font(.system(size: 13))
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack {
                Text(Plural.positions(viewModel.itemCount))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.inkSecondary)
                Spacer()
                Text(Money.string(viewModel.total))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
            }

            Button {
                viewModel.sendToKitchen()
            } label: {
                Text(viewModel.hasUnsent ? "Отправить на кухню" : "Всё отправлено")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.hasUnsent)
            .opacity(viewModel.hasUnsent ? 1 : 0.55)

            Button {
                viewModel.pay()
            } label: {
                Text("Оплатить · \(Money.string(viewModel.total))")
            }
            .buttonStyle(PrimaryButtonStyle(tint: Theme.green))
            .disabled(viewModel.lines.isEmpty)
            .opacity(viewModel.lines.isEmpty ? 0.55 : 1)
        }
        .padding(.horizontal, Constants.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}
