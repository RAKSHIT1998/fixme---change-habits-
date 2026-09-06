import SwiftUI

/// The in-app manual.
///
/// Several things in Fix Me aren't self-evident — quit habits count as kept by default,
/// a streak freeze can rescue a missed day, and friends work phone-to-phone with no
/// account. Explaining those once, in plain language, is cheaper than losing people who
/// assumed the app worked some other way.
struct HowToUseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<String> = ["start"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.md) {
                    header

                    ForEach(GuideSection.all) { section in
                        GuideCard(
                            section: section,
                            isExpanded: expanded.contains(section.id)
                        ) {
                            withAnimation(FMTheme.Motion.snappy) {
                                if expanded.contains(section.id) {
                                    expanded.remove(section.id)
                                } else {
                                    expanded.insert(section.id)
                                }
                            }
                        }
                    }

                    Text("Fix Me is a tracker, not medical care. Health timelines shown for quitting are general published figures, not advice about you.")
                        .font(.system(size: 11))
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, FMTheme.Spacing.sm)
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("How Fix Me works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
            Text("90 days, one day at a time.")
                .font(FMTheme.Typography.display(28))
                .foregroundStyle(FMTheme.Colors.textPrimary)
            Text("The whole app is built around winning today. Everything below is optional — you can get the full value from just the Today screen.")
                .font(FMTheme.Typography.body)
                .foregroundStyle(FMTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Content

struct GuideStep: Identifiable {
    let id = UUID()
    let text: String
    var detail: String? = nil
}

struct GuideSection: Identifiable {
    let id: String
    let number: Int
    let title: String
    let symbol: String
    let summary: String
    let steps: [GuideStep]

    static let all: [GuideSection] = [
        GuideSection(
            id: "start", number: 1, title: "Getting started", symbol: "flag.fill",
            summary: "Pick a few habits and start your 90 days.",
            steps: [
                GuideStep(text: "Choose the areas you want to change, then pick your habits.",
                          detail: "Start smaller than feels impressive. Three habits you actually do beats seven you don't."),
                GuideStep(text: "Say whether you want to quit anything — smoking, alcohol, vaping.",
                          detail: "Optional. \"None of these\" is a completely normal answer."),
                GuideStep(text: "Give your name, then tap START MY 90 DAYS."),
            ]
        ),
        GuideSection(
            id: "today", number: 2, title: "Your day", symbol: "sun.max.fill",
            summary: "The Today tab is the only screen you need most days.",
            steps: [
                GuideStep(text: "Tap a habit to complete it.",
                          detail: "What happens depends on the habit: simple ones complete instantly, water-style ones open a quick +250ml logger, and step habits fill in from Apple Health on their own."),
                GuideStep(text: "Habits marked PROVE IT open the camera.",
                          detail: "Take a quick photo and the app checks whether it looks consistent with your habit. It'll say when it can't tell — an unverified photo never costs you one of your free checks."),
                GuideStep(text: "The ring at the top is today's completion. Long-press any habit to see its history."),
                GuideStep(text: "Tap + to add a habit at any time."),
            ]
        ),
        GuideSection(
            id: "quit", number: 3, title: "Quitting something", symbol: "nosign",
            summary: "A counter that runs, rather than a box you tick.",
            steps: [
                GuideStep(text: "Quit habits count as kept automatically.",
                          detail: "You don't tick them off each day. They stay green unless you log a relapse — so doing nothing is success here."),
                GuideStep(text: "Tap the habit for clean time, money saved and your recovery timeline."),
                GuideStep(text: "Hit \"I'm having a craving\" when one strikes.",
                          detail: "A five-minute timer with paced breathing. Cravings usually pass in minutes — outlasting one counts as progress and earns XP."),
                GuideStep(text: "If you slip, log it honestly.",
                          detail: "Only the current run resets. Your total clean time, longest run and cravings beaten all survive — relapsing is part of quitting, not the end of it."),
            ]
        ),
        GuideSection(
            id: "streaks", number: 4, title: "Streaks and missed days", symbol: "flame.fill",
            summary: "One bad day is not meant to cost you the month.",
            steps: [
                GuideStep(text: "Complete everything in a day to extend your streak."),
                GuideStep(text: "Miss a day and you'll get a recovery card, not a telling-off."),
                GuideStep(text: "Use a streak freeze to rescue a missed day.",
                          detail: "Everyone gets one a month free; Premium gets three. It restores the run you'd built, but earns no XP — it's protection, not a shortcut."),
            ]
        ),
        GuideSection(
            id: "alarms", number: 5, title: "Alarms and reminders", symbol: "alarm.fill",
            summary: "Wake-ups with a Done button on the lock screen.",
            steps: [
                GuideStep(text: "Profile → Alarms → + to add one. Set a time and which days it repeats."),
                GuideStep(text: "Link a habit and the notification gets a Done button.",
                          detail: "You can mark the habit complete without unlocking or opening the app."),
                GuideStep(text: "These are Time Sensitive notifications, not true alarms.",
                          detail: "They break through most Focus modes, but iOS doesn't let any third-party app ring through Silent mode or Do Not Disturb. For anything you truly can't miss, keep a Clock alarm as backup."),
            ]
        ),
        GuideSection(
            id: "night", number: 6, title: "Closing the day", symbol: "moon.stars.fill",
            summary: "Two minutes at night that make the other 23 hours count.",
            steps: [
                GuideStep(text: "Tap \"Finish your day\" on Today."),
                GuideStep(text: "Review what got done, write a line, add a photo if you want."),
                GuideStep(text: "Complete the day to see your score, then share it, post it to your wall, or send it to a friend."),
            ]
        ),
        GuideSection(
            id: "friends", number: 7, title: "Friends, without an account", symbol: "person.2.fill",
            summary: "Phone-to-phone. No sign-up, no server, no database.",
            steps: [
                GuideStep(text: "Social → Friends → add someone."),
                GuideStep(text: "Together in person? Use Nearby.",
                          detail: "Both phones connect directly over Wi-Fi and Bluetooth. Check the short code matches theirs before adding — only add a phone that's actually in front of you."),
                GuideStep(text: "Far apart? Send an invite link through any messaging app."),
                GuideStep(text: "Share progress the same two ways, and only the fields you tick.",
                          detail: "Every update is signed by your device, so a friend's app can tell a real update from a faked one."),
                GuideStep(text: "Nobody can push to you.",
                          detail: "With no server, updates arrive when you're near each other with the app open, or when someone sends you a link. Open the tab now and then."),
            ]
        ),
        GuideSection(
            id: "privacy", number: 8, title: "Your data", symbol: "lock.fill",
            summary: "It stays on your device unless you send it somewhere.",
            steps: [
                GuideStep(text: "Habits, photos, journals and friends are stored locally."),
                GuideStep(text: "Delete verification photos whenever you like, or all of them at once in Settings."),
                GuideStep(text: "Export everything as a JSON file from Settings → Your data."),
                GuideStep(text: "Health data is read-only and only for habits that need it.",
                          detail: "If you skip the Health permission, those habits just fall back to tapping them yourself."),
            ]
        ),
    ]
}

// MARK: - Card

private struct GuideCard: View {
    let section: GuideSection
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
            Button(action: onToggle) {
                HStack(spacing: FMTheme.Spacing.sm) {
                    Text("\(section.number)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(FMTheme.Colors.accent, in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(section.title)
                            .font(FMTheme.Typography.headline)
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        Text(section.summary)
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FMTheme.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
                    ForEach(Array(section.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: FMTheme.Spacing.xs) {
                            Text("\(index + 1).")
                                .font(FMTheme.Typography.footnote)
                                .foregroundStyle(FMTheme.Colors.accent)
                                .frame(width: 18, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.text)
                                    .font(FMTheme.Typography.subheadline)
                                    .foregroundStyle(FMTheme.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let detail = step.detail {
                                    Text(detail)
                                        .font(FMTheme.Typography.footnote)
                                        .foregroundStyle(FMTheme.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(FMTheme.Spacing.md)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityHint(isExpanded ? "Expanded" : "Collapsed. Double tap to expand.")
    }
}

#Preview {
    HowToUseView()
}
