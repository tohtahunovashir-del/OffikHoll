import Foundation
import SwiftUI

struct OrderBottomBar: View {
    let itemCount: Int
    let total: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Text("\(itemCount)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }

                if itemCount == 0 {
                    Text("Заказ пуст")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.ink)
                } else {
                    HStack(spacing: 5) {
                        Text(Plural.positions(itemCount))
                            .foregroundColor(Theme.ink)
                        Text("•")
                            .foregroundColor(Theme.inkTertiary)
                        Text(Money.string(total))
                            .foregroundColor(Theme.accent)
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.inkSecondary)
            }
            .padding(.horizontal, Constants.screenPadding)
            .frame(height: Constants.bottomBarHeight)
            .background(
                Theme.background
                    .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: -3)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(itemCount == 0)
    }
}
