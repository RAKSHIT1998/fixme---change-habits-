import SwiftUI

/// You and your partner, side by side.
///
/// Their number only moves when they actually send an update — there is no server to poll,
/// and pretending otherwise by showing a stale figure as current would be a lie the user
/// can't see. So the row says when it last heard from them.
struct PactRow: View {
    let pact: Pact
    let myDayNumber: Int?
    let partnerUpdate: FriendUpdate?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                HStack {
                    Text("🤝").font(.system(size: 20))
                    Text(pact.hasStarted ? "You & \(pact.partnerName)" : "Starting with \(pact.partnerName)")
                        .font(FMTheme.Typography.subheadline)
                        .foregroundStyle(FMTheme.Colors.textPrimary)
                    Spacer(minLength: 0)
                }

                if pact.hasStarted {
                    HStack(spacing: FMTheme.Spacing.md) {
                        side(name: "You", day: myDayNumber, caption: nil)
                        Divider().frame(height: 32)
                        side(
                            name: pact.partnerName,
                            day: partnerUpdate?.dayNumber,
                            caption: partnerCaption
                        )
                    }
                } else {
                    Text(startsCaption)
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                if !pact.startsAligned {
                    Text("Your run started on a different day, so the numbers won't match.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                }
            }
            .padding(FMTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var startsCaption: String {
        let days = pact.daysUntilStart()
        switch days {
        case 0: return "You both start today."
        case 1: return "You both start tomorrow."
        default: return "You both start in \(days) days."
        }
    }

    private var partnerCaption: String? {
        guard let partnerUpdate else { return "No update yet" }
        return "Sent \(partnerUpdate.createdAt.formatted(.relative(presentation: .named)))"
    }

    private func side(name: String, day: Int?, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name)
                .font(FMTheme.Typography.footnote)
                .foregroundStyle(FMTheme.Colors.textSecondary)
            Text(day.map { "Day \($0)" } ?? "—")
                .font(FMTheme.Typography.headline)
                .foregroundStyle(FMTheme.Colors.textPrimary)
            if let caption {
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(FMTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 12) {
        PactRow(pact: Pact(partnerPeerID: "x", partnerName: "Sam",
                           startDate: .now.addingTimeInterval(-86_400 * 11)),
                myDayNumber: 12, partnerUpdate: nil) {}
        PactRow(pact: Pact(partnerPeerID: "x", partnerName: "Sam",
                           startDate: .now.addingTimeInterval(86_400 * 3)),
                myDayNumber: nil, partnerUpdate: nil) {}
    }
    .padding()
}
