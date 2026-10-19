import SwiftUI

struct FloorView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var floor: FloorStore
    @AppStorage("venueName") private var venueName = "OffikHoll"
    @AppStorage("waiterName") private var waiterName = "Официант"

    @State private var path = NavigationPath()
    @State private var selectedZone = "Все столы"
    @State private var editorTarget: TableEditorTarget?
    @State private var tableToDelete: RestaurantTable?

    private enum TableEditorTarget: Identifiable {
        case new
        case edit(RestaurantTable)

        var id: String {
            switch self {
            case .new:
                return "new"
            case let .edit(table):
                return "edit-\(table.id)"
            }
        }

        var table: RestaurantTable? {
            switch self {
            case .new:
                return nil
            case let .edit(table):
                return table
            }
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 158, maximum: 230), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        statsCard
                        serviceLine
                        zoneChips
                        tablesGrid
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: OrderRoute.self) { route in
                OrderScreen(orderId: route.orderId, database: environment.database)
            }
            .sheet(item: $editorTarget) { target in
                TableEditorView(existingTable: target.table)
                    .environmentObject(floor)
            }
            .confirmationDialog(
                "Удалить стол № \(tableToDelete?.number ?? 0)?",
                isPresented: Binding(
                    get: { tableToDelete != nil },
                    set: { if !$0 { tableToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить стол", role: .destructive) {
                    if let table = tableToDelete {
                        if let error = floor.deleteTable(table) {
                            floor.errorMessage = error
                            Haptics.error()
                        } else {
                            Haptics.success()
                        }
                    }
                    tableToDelete = nil
                }
                Button("Отмена", role: .cancel) {
                    tableToDelete = nil
                }
            } message: {
                Text("Стол исчезнет с карты зала. Занятый стол удалить нельзя.")
            }
            .errorAlert($floor.errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        ScreenHeader(
            eyebrow: "\(venueName) · \(waiterName)",
            title: "Зал",
            subtitle: dateLine
        ) {
            HStack(spacing: 8) {
                Button {
                    Haptics.impact(.light)
                    editorTarget = .new
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.accentFill))
                        .shadow(color: Palette.accentFill.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить стол")
            }
        }
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        let date = formatter.string(from: Date())
        return date.prefix(1).uppercased() + String(date.dropFirst())
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            StatBlock(
                title: "Свободно",
                value: "\(floor.stats.freeTables)",
                tint: Palette.accent
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            verticalDivider

            StatBlock(
                title: "Занято",
                value: "\(floor.stats.occupiedTables)",
                tint: Palette.gold
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 18)

            verticalDivider

            StatBlock(
                title: "Выручка сегодня",
                value: Price.compact(floor.stats.revenueToday),
                tint: Palette.ink,
                alignment: .trailing
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 18)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .premiumCard(padding: 0, cornerRadius: 20)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(width: 1, height: 34)
            .padding(.horizontal, 4)
    }

    private var serviceLine: some View {
        HStack(spacing: 14) {
            MetaLabel(
                icon: "list.bullet.rectangle",
                text: "\(floor.stats.openOrders) \(AppFormat.plural(floor.stats.openOrders, "открытый заказ", "открытых заказа", "открытых заказов"))"
            )
            Spacer(minLength: 0)
            MetaLabel(
                icon: "person.3.fill",
                text: "\(floor.stats.guests) \(AppFormat.plural(floor.stats.guests, "гость", "гостя", "гостей"))"
            )
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Zones & grid

    private var zoneChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Все столы",
                    count: floor.cards.count,
                    isSelected: selectedZone == "Все столы"
                ) {
                    selectedZone = "Все столы"
                }
                ForEach(floor.zones, id: \.self) { zone in
                    FilterChip(
                        title: zone,
                        count: floor.cards(in: zone).count,
                        isSelected: selectedZone == zone
                    ) {
                        selectedZone = zone
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var tablesGrid: some View {
        let cards = floor.cards(in: selectedZone)
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Карта столов")
            if cards.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: "Столов пока нет",
                    message: "Добавьте первый стол, чтобы начать принимать заказы.",
                    actionTitle: "Добавить стол"
                ) {
                    editorTarget = .new
                }
                .premiumCard(padding: 6, cornerRadius: 24)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(cards) { card in
                        Button {
                            openOrder(for: card)
                        } label: {
                            TableCardView(card: card)
                        }
                        .buttonStyle(TableCardButtonStyle())
                        .contextMenu {
                            Button {
                                openOrder(for: card)
                            } label: {
                                Label("Открыть заказ", systemImage: "arrow.up.right.square")
                            }
                            Button {
                                editorTarget = .edit(card.table)
                            } label: {
                                Label("Редактировать стол", systemImage: "slider.horizontal.3")
                            }
                            Button(role: .destructive) {
                                tableToDelete = card.table
                            } label: {
                                Label("Удалить стол", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func openOrder(for card: FloorCard) {
        Haptics.impact(.medium)
        if let orderId = floor.openOrder(for: card.table) {
            path.append(OrderRoute(orderId: orderId))
        }
    }
}
