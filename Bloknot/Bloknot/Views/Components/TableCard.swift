import Foundation
import SwiftUI

struct TableCard: View {
    let summary: TableSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text("\(summary.table.number)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                Circle()
                    .fill(summary.status.color)
                    .frame(width: 10, height: 10)
                    .padding(.top, 8)
            }

            Text(summary.status.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(summary.status.color)
                .lineLimit(1)

            Spacer(minLength: 2)

            if summary.orderId != nil {
                Text(Money.compact(summary.total))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(Plural.positions(summary.itemCount))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.inkSecondary)
                    .lineLimit(1)
            } else {
                Text("\(summary.table.seats) мест")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.inkSecondary)

                Text(summary.table.zone)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.inkTertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .stroke(summary.status.color.opacity(summary.orderId == nil ? 0.18 : 0.5), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(Constants.cardShadowOpacity),
            radius: Constants.cardShadowRadius,
            x: 0,
            y: Constants.cardShadowY
        )
    }
}
