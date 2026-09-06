import SwiftUI

/// Invite loop.
///
/// Word of mouth is the cheapest acquisition a habit app has, and accountability is a
/// genuine feature here rather than a growth gimmick — people who start a 90-day
/// challenge alongside someone else finish it more often. The offer is symmetric: both
/// sides get a free week, so sharing it doesn't feel like spamming your friends.
struct ReferralView: View {
    let user: User?

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    private var code: String { user?.referralCode ?? "FIXME1" }

    /// The link matters more than the code. Sharing a bare code asks the other person to
    /// go and find the app themselves, which is where most of this funnel used to leak.
    private var inviteLink: URL { InviteLink.referral(code: code) }

    private var inviteMessage: String {
        """
        I'm doing a 90-day habit reset in Fix Me. Want to do it with me?

        \(inviteLink.absoluteString)

        My code is \(code) — we both get a free week of Premium.
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FMTheme.Spacing.lg) {
                    Text("🤝").font(.system(size: 56)).padding(.top, FMTheme.Spacing.lg)

                    VStack(spacing: FMTheme.Spacing.xs) {
                        Text("Do it with someone.")
                            .font(FMTheme.Typography.display(30))
                            .multilineTextAlignment(.center)
                        Text("Invite a friend to your 90 days. You both get a free week of Premium when they start.")
                            .font(FMTheme.Typography.body)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 6) {
                        Text("YOUR CODE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(FMTheme.Colors.textTertiary)
                        Text(code)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(FMTheme.Colors.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(FMTheme.Spacing.lg)
                    .background(FMTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))

                    if let user, user.referralsConverted > 0 {
                        Text("\(user.referralsConverted) friend\(user.referralsConverted == 1 ? "" : "s") joined. Nice.")
                            .font(FMTheme.Typography.subheadline)
                            .foregroundStyle(FMTheme.Colors.success)
                    }

                    FMPrimaryButton(title: "Invite a friend", icon: "square.and.arrow.up") {
                        services.analytics.track(.referralShared)
                        showShareSheet = true
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityShareSheet(items: [inviteMessage, inviteLink])
            }
        }
    }
}

#Preview {
    ReferralView(user: User(name: "Alex"))
}
