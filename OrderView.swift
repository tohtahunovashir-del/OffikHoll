import SwiftUI

struct OrderView: View {
    @EnvironmentObject private var store: RestaurantStore
    @Environment(\.dismiss) private var dismiss
    let table: DiningTable
    @State private var showingOrder = false
    @State private var searchText = ""
    @State private var showingSearch = false

    private var selectedCategory: Category? {
        store.categories.first(where: { $0.id == store.selectedCategoryID }) ?? store.categories.first
    }
    private var filteredItems: [MenuItem] {
        store.menuItems.filter { item in
            searchText.isEmpty
                ? item.categoryId == selectedCategory?.id
                : item.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    private let itemColumns = [GridItem(.adaptive(minimum: 130), spacing: 11)]

    var body: some View {
        VStack(spacing: 0) {
            if showingSearch {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Найти блюдо", text: $searchText)
                        .textInputAutocapitalization(.never)
                    Button { searchText = ""; showingSearch = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 14).padding(.top, 8)
            }
            HStack(spacing: 0) {
                categoryRail
                    .frame(width: 112)
                Rectangle().fill(Color(uiColor: .separator).opacity(0.35)).frame(width: 1)
                menuGrid
            }
            .padding(.top, 10)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            orderSummaryBar
        }
        .navigationTitle("Стол \(table.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingSearch.toggle() } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Поиск по меню")
            }
        }
        .onAppear { store.openTable(table) }
        .onChange(of: store.activeOrder?.id) { orderID in
            if orderID == nil { dismiss() }
        }
        .sheet(isPresented: $showingOrder) {
            if store.activeOrder != nil {
                OrderDetailView(tableNumber: table.number)
                    .environmentObject(store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var categoryRail: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                ForEach(store.categories) { category in
                    let selected = category.id == selectedCategory?.id
                    Button {
                        store.selectedCategoryID = category.id
                        searchText = ""
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: icon(for: category.name))
                                .font(.system(size: 18, weight: .semibold))
                            Text(category.name)
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.78))
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .padding(.horizontal, 4)
                        .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
        }
    }

    private var menuGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedCategory?.name ?? "Меню")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("\(filteredItems.count) блюд")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                LazyVGrid(columns: itemColumns, spacing: 11) {
                    ForEach(filteredItems) { item in
                        Button { store.add(item) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                                HStack {
                                    Text(item.price.formatted(.number.precision(.fractionLength(0...2))) + " ₽")
                                        .font(.subheadline.weight(.bold)).foregroundStyle(Color.accentColor)
                                    Spacer(minLength: 0)
                                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Добавить \(item.name), \(item.price.formatted()) рублей")
                    }
                }
                .padding(.horizontal, 12)
                if filteredItems.isEmpty {
                    EmptyStateView(title: "В этой категории пока пусто", subtitle: "Добавьте блюда во вкладке «Меню»", symbol: "fork.knife")
                        .padding(.top, 30)
                }
            }
            .padding(.top, 5).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
    }

    private var orderSummaryBar: some View {
        Button { showingOrder = true } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(Color.accentColor.opacity(0.14)).frame(width: 46, height: 46)
                    Image(systemName: "basket.fill").foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Текущий заказ").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("\(store.orderItems.reduce(0) { $0 + $1.quantity }) позиций")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text((store.activeOrder?.totalAmount ?? 0).formatted(.number.precision(.fractionLength(0...2))) + " ₽")
                    .font(.headline.weight(.bold)).foregroundStyle(.primary)
                Image(systemName: "chevron.up").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).frame(height: 76)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Rectangle().fill(Color(uiColor: .separator).opacity(0.3)).frame(height: 0.5) }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Открыть подробности заказа")
    }

    private func icon(for name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("закус"): return "takeoutbag.and.cup.and.straw.fill"
        case let n where n.contains("салат"): return "leaf.fill"
        case let n where n.contains("суп"): return "cup.and.saucer.fill"
        case let n where n.contains("горяч") || n.contains("паста"): return "flame.fill"
        case let n where n.contains("десерт") || n.contains("выпеч"): return "birthday.cake.fill"
        case let n where n.contains("напит"): return "wineglass.fill"
        default: return "square.grid.2x2.fill"
        }
    }
}

struct OrderDetailView: View {
    @EnvironmentObject private var store: RestaurantStore
    @Environment(\.dismiss) private var dismiss
    let tableNumber: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.orderItems.isEmpty {
                    EmptyStateView(title: "Заказ пока пуст", subtitle: "Добавьте блюда из меню одним касанием", symbol: "basket")
                } else {
                    List {
                        ForEach(store.orderItems) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.itemName).font(.subheadline.weight(.semibold))
                                    Text(item.unitPrice.formatted(.number.precision(.fractionLength(0...2))) + " ₽ за шт.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 5)
                                HStack(spacing: 8) {
                                    quantityButton("minus", label: "Уменьшить количество") { store.changeQuantity(item, by: -1) }
                                    Text("\(item.quantity)").font(.subheadline.monospacedDigit().weight(.semibold)).frame(minWidth: 22)
                                    quantityButton("plus", label: "Увеличить количество") { store.changeQuantity(item, by: 1) }
                                }
                                Text((Double(item.quantity) * item.unitPrice).formatted(.number.precision(.fractionLength(0...2))) + " ₽")
                                    .font(.subheadline.weight(.bold)).frame(minWidth: 64, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                VStack(spacing: 12) {
                    HStack {
                        Text("Итого").font(.headline)
                        Spacer()
                        Text((store.activeOrder?.totalAmount ?? 0).formatted(.number.precision(.fractionLength(0...2))) + " ₽")
                            .font(.title3.weight(.bold))
                    }
                    HStack(spacing: 10) {
                        Button { store.sendToKitchen() } label: {
                            Label("На кухню", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.accentColor)
                        Button {
                            store.payAndClose()
                            dismiss()
                        } label: {
                            Label("Оплата", systemImage: "creditcard.fill")
                                .frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle("Заказ · Стол \(tableNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Готово") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(store.activeOrder?.status.rawValue ?? "")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func quantityButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.caption.weight(.bold))
                .frame(width: 36, height: 36)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}
