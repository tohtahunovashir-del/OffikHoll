import Foundation
import SwiftUI

/// Маршрут «стол → счёт». Держит и стол, и открытый заказ, чтобы экран
/// заказа не создавал счёт повторно.
struct OrderRoute: Hashable {
    let table: DiningTable
    let orderId: UUID
}

struct TablesGridView: View {
    @StateObject private var viewModel = TablesViewModel()
    @State private var path = NavigationPath()
    @State private var isShowingMenuEditor = false
    @AppStorage(Constants.venueNameKey) private var venueName: String = Constants.defaultVenueName

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: Constants.tableColumns
    )

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Constants.spacing) {
                    statsRow

                    if viewModel.summaries.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.summaries) { summary in
                                Button {
                                    open(summary)
                                } label: {
                                    TableCard(summary: summary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Constants.screenPadding)
                .padding(.vertical, 12)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(venueName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingMenuEditor = true
                    } label: {
                        Label("Меню", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationDestination(for: OrderRoute.self) { route in
                OrderView(table: route.table, orderId: route.orderId)
            }
            .sheet(isPresented: $isShowingMenuEditor) {
                MenuEditorView()
            }
            .alert("Ошибка", isPresented: errorBinding) {
                Button("Понятно", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Pieces

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(title: "Свободно", value: "\(viewModel.freeCount)", tint: Theme.green)
            statCard(title: "Занято", value: "\(viewModel.occupiedCount)", tint: Theme.yellow)
            statCard(title: "В зале", value: Money.compact(viewModel.totalAmount), tint: Theme.accent)
        }
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.inkSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.card)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Theme.inkTertiary)
            Text(viewModel.isLoading ? "Загружаем зал…" : "Столов пока нет")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }

    // MARK: - Actions

    private func open(_ summary: TableSummary) {
        HapticsService.tap()
        guard let orderId = viewModel.openOrder(for: summary.table) else { return }
        path.append(OrderRoute(table: summary.table, orderId: orderId))
    }
}
