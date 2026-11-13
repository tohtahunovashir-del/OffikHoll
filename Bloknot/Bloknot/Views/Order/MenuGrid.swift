import Foundation
import SwiftUI

struct MenuGrid: View {
    let items: [MenuItem]
    let quantity: (UUID) -> Int
    let onTap: (MenuItem) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: Constants.dishColumns
    )

    init(items: [MenuItem], quantity: @escaping (UUID) -> Int, onTap: @escaping (MenuItem) -> Void) {
        self.items = items
        self.quantity = quantity
        self.onTap = onTap
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(Theme.inkTertiary)
                    Text("В этой категории пока нет блюд")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            onTap(item)
                        } label: {
                            DishCard(item: item, quantity: quantity(item.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
        }
    }
}
