import SwiftUI
import GRDB

/// iikoWaiter-style order workspace:
/// categories on the left, dishes on the right, one tap adds a dish and the
/// bill lives in a compact bar at the bottom. On iPad the bill is a third
/// permanently visible column.
struct OrderScreen: View {
    @EnvironmentObject private var menu: MenuStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var store: OrderStore
    @State private var selectedCategoryId: UUID?
    @State private var searchText = ""
    @State private var showDetail = false
    @State private var closeHandled = false

    init(orderId: UUID, database: DatabaseQueue) {
        _store = StateObject(wrappedValue: OrderStore(database: database, orderId: orderId))
    }

    private var isRegular: Bool { horizontalSizeClass == .regular }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 120, maximum: 220), spacing: 10)
    ]

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header
                Rectangle()
                    .fill(Palette.stroke)
                    .frame(height: 1)

                if isRegular {
                    HStack(spacing: 0) {
                        rail.frame(width: 108)
                        verticalDivider
                        menuPanel
                        verticalDivider
                        OrderDetailEmbedded(store: store) {
                            dismiss()
                        }
                        .frame(width: 340)
                    }
                } else {
                    HStack(spacing: 0) {
                        rail.frame(width: 98)
                        verticalDivider
                        menuPanel
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isRegular {
                OrderSummaryBar(store: store) {
                    showDetail = true
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            OrderDetailView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            if selectedCategoryId == nil {
                selectedCategoryId = firstUsefulCategory
            }
        }
        .onChange(of: menu.categories) { newCategories in
            if let current = selectedCategoryId,
               newCategories.contains(where: { $0.id == current }) {
                return
            }
            selectedCategoryId = newCategories.first(where: { menu.itemCount(in: $0.id) > 0 })?.id
                ?? newCategories.first?.id
        }
        .onChange(of: store.didClose) { didClose in
            guard didClose, !closeHandled else { return }
            closeHandled = true
            showDetail = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                dismiss()
            }
        }
        .errorAlert($store.errorMessage)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            CircleIconButton(icon: "chevron.left", accessibilityTitle: "Назад") {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("СТОЛ \(store.tableNumber) · \(store.status.title.uppercased())")
                    .font(.system(size: 9.5, weight: .semibold))
                    .kerning(1.3)
                    .foregroundColor(Palette.gold)
                HStack(spacing: 8) {
                    Text("Заказ")
                        .font(Typeface.display(25, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    if store.isPaid {
                        StatusPill(text: "Оплачен", color: Palette.paid)
                    }
                }
            }

            Spacer(minLength: 6)

            Menu {
                Picker("Гости", selection: Binding(
                    get: { store.guests },
                    set: { store.updateGuests($0) }
                )) {
                    ForEach(1...16, id: \.self) { count in
                        Text("\(count) гостей").tag(count)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(store.guests)")
                        .font(Typeface.number(14, weight: .semibold))
                }
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Количество гостей")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(width: 1)
    }

    // MARK: - Categories

    private var rail: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 7) {
                if menu.categories.isEmpty {
                    Text("Нет категорий")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)
                } else {
                    ForEach(menu.categories) { category in
                        CategoryRailButton(
                            category: category,
                            count: menu.itemCount(in: category.id),
                            isSelected: selectedCategoryId == category.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedCategoryId = category.id
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Dishes

    private var menuPanel: some View {
        VStack(spacing: 10) {
            SearchField(placeholder: "Поиск блюда", text: $searchText)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(panelTitle)
                            .font(Typeface.display(21, weight: .semibold))
                            .foregroundColor(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(filteredItems.count)")
                            .font(Typeface.number(12, weight: .semibold))
                            .foregroundColor(Palette.inkTertiary)
                    }
                    .padding(.horizontal, 12)

                    if filteredItems.isEmpty {
                        EmptyStateView(
                            icon: searchText.isEmpty ? "fork.knife" : "magnifyingglass",
                            title: searchText.isEmpty ? "Здесь пока пусто" : "Ничего не найдено",
                            message: searchText.isEmpty
                                ? "Добавьте блюда в этой категории в разделе «Меню»."
                                : "Попробуйте другое название блюда."
                        )
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(filteredItems) { item in
                                DishCard(
                                    item: item,
                                    quantity: store.quantity(for: item.id)
                                ) {
                                    Haptics.impact(.light)
                                    store.add(item)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 120)
            }
        }
    }

    private var panelTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Поиск"
        }
        return menu.categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Меню"
    }

    private var firstUsefulCategory: UUID? {
        menu.categories.first(where: { menu.itemCount(in: $0.id) > 0 })?.id
            ?? menu.categories.first?.id
    }

    private var filteredItems: [MenuItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [MenuItem]
        if query.isEmpty {
            guard let selectedCategoryId else { return [] }
            base = menu.items(in: selectedCategoryId)
        } else {
            base = menu.items.filter { $0.searchableText.contains(query) }
        }
        return base.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
