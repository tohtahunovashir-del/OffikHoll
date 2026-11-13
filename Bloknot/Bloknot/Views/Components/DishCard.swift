import Foundation
import SwiftUI

struct DishCard: View {
    let item: MenuItem
    var quantity: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Text(Money.compact(item.price))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .fill(Theme.card)
        )
        .shadow(
            color: Color.black.opacity(Constants.cardShadowOpacity),
            radius: Constants.cardShadowRadius,
            x: 0,
            y: Constants.cardShadowY
        )
        .overlay(alignment: .topTrailing) {
            if quantity > 0 {
                Text("\(quantity)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Circle().fill(Theme.accent))
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
    }
}
