import Foundation
import SwiftUI

struct OrderItemRow: View {
    let line: OrderItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(line.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(Money.string(line.price))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.inkSecondary)

                    if line.isSent {
                        Text("на кухне")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.redSoft))
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 0) {
                stepperButton(systemName: "minus", action: onDecrement)
                Text("\(line.quantity)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .frame(width: 28)
                stepperButton(systemName: "plus", action: onIncrement)
            }
            .background(Capsule().fill(Theme.secondaryBackground))
        }
        .padding(.vertical, 2)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
