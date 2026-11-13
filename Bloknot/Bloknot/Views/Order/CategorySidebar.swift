import Foundation
import SwiftUI

struct CategorySidebar: View {
    let categories: [Category]
    let selectedId: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(categories) { category in
                    Button {
                        onSelect(category.id)
                    } label: {
                        Text(category.name)
                            .font(
                                .system(
                                    size: 14,
                                    weight: selectedId == category.id ? .semibold : .regular
                                )
                            )
                            .foregroundColor(selectedId == category.id ? Theme.accent : Theme.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedId == category.id ? Theme.accentSoft : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
    }
}
