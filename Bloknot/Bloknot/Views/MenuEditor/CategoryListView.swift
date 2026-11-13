import Foundation
import SwiftUI

struct CategoryListView: View {
    @ObservedObject var viewModel: MenuEditorViewModel
    let category: Category

    @State private var isShowingForm = false

    init(viewModel: MenuEditorViewModel, category: Category) {
        self.viewModel = viewModel
        self.category = category
    }

    var body: some View {
        List {
            if viewModel.items(in: category.id).isEmpty {
                Text("Пока пусто. Добавьте блюдо кнопкой «+».")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.inkSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.items(in: category.id)) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.ink)
                            Text(Money.string(item.price))
                                .font(.system(size: 12))
                                .foregroundColor(Theme.inkSecondary)
                        }
                        Spacer(minLength: 0)
                        if !item.isAvailable {
                            Text("стоп")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.red)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.redSoft))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete(perform: delete)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingForm) {
            MenuItemFormView(
                categories: viewModel.categories,
                category: category
            ) { name, priceText, categoryId in
                viewModel.addDish(name: name, priceText: priceText, categoryId: categoryId)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = viewModel.items(in: category.id)
        for index in offsets where index < items.count {
            viewModel.deleteItem(items[index])
        }
    }
}
