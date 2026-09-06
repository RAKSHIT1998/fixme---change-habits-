import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var users: [User]
    @Query(filter: #Predicate<Journey> { $0.isActive }, sort: \Journey.startDate, order: .reverse)
    private var activeJourneys: [Journey]
    @State private var showSettings = false
    @State private var showAlarms = false
    @State private var showHowTo = false

    private var user: User? { users.first }
    private var journey: Journey? { activeJourneys.first }

    private var totalHabitsCompleted: Int {
        journey?.habits.reduce(0) { $0 + $1.completions.filter { $0.state.isDone }.count } ?? 0
    }

    private var bestStreak: Int {
        journey?.habits.map { $0.currentStreak() }.max() ?? 0
    }

    private var unlockedBadgeIDs: Set<String> {
        Set(user?.badges.map { $0.badgeIdentifier } ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FMTheme.Spacing.lg) {
                    header

                    if let journey {
                        HStack(spacing: FMTheme.Spacing.sm) {
                            StatTile(value: "\(journey.dayNumber())/\(journey.lengthInDays)", label: "Journey")
                            StatTile(value: "\(bestStreak)", label: "Best streak")
                            StatTile(value: "\(totalHabitsCompleted)", label: "Habits done")
                        }
                    }

                    Button { showHowTo = true } label: {
                        HStack(spacing: FMTheme.Spacing.sm) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(FMTheme.Colors.accent)
                                .frame(width: 32, height: 32)
                                .background(FMTheme.Colors.accent.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text("How Fix Me works")
                                    .font(FMTheme.Typography.headline)
                                    .foregroundStyle(FMTheme.Colors.textPrimary)
                                Text("A short guide to every part of the app")
                                    .font(FMTheme.Typography.footnote)
                                    .foregroundStyle(FMTheme.Colors.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FMTheme.Colors.textTertiary)
                        }
                        .padding(FMTheme.Spacing.md)
                        .background(FMTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button { showAlarms = true } label: {
                        HStack(spacing: FMTheme.Spacing.sm) {
                            Image(systemName: "alarm.fill")
                                .foregroundStyle(FMTheme.Colors.accent)
                                .frame(width: 32, height: 32)
                                .background(FMTheme.Colors.accent.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Alarms")
                                    .font(FMTheme.Typography.headline)
                                    .foregroundStyle(FMTheme.Colors.textPrimary)
                                Text("Wake-ups and reminders with a Done button")
                                    .font(FMTheme.Typography.footnote)
                                    .foregroundStyle(FMTheme.Colors.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FMTheme.Colors.textTertiary)
                        }
                        .padding(FMTheme.Spacing.md)
                        .background(FMTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.sm) {
                        Text("Badges").font(FMTheme.Typography.headline).foregroundStyle(FMTheme.Colors.textPrimary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FMTheme.Spacing.sm) {
                            ForEach(BadgeDefinition.all) { def in
                                BadgeTile(definition: def, isUnlocked: unlockedBadgeIDs.contains(def.id))
                            }
                        }
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showAlarms) {
                AlarmsView()
            }
            .sheet(isPresented: $showHowTo) {
                HowToUseView()
            }
        }
    }

    private var header: some View {
        VStack(spacing: FMTheme.Spacing.sm) {
            Image(systemName: user?.avatarSystemImage ?? "person.crop.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(FMTheme.Colors.accent)
            Text(user?.name ?? "You").font(FMTheme.Typography.title)
            Text(user?.transformationLevel.title ?? TransformationLevel.gettingStarted.title)
                .font(FMTheme.Typography.subheadline)
                .foregroundStyle(FMTheme.Colors.textSecondary)
            Text("\(user?.totalXP ?? 0) XP")
                .font(FMTheme.Typography.caption)
                .foregroundStyle(FMTheme.Colors.accent)
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(FMTheme.Typography.title2).foregroundStyle(FMTheme.Colors.textPrimary)
            Text(label).font(FMTheme.Typography.footnote).foregroundStyle(FMTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMTheme.Spacing.sm)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
    }
}

private struct BadgeTile: View {
    let definition: BadgeDefinition
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(definition.emoji).font(.system(size: 28)).opacity(isUnlocked ? 1 : 0.25)
            Text(definition.title).font(FMTheme.Typography.footnote).foregroundStyle(isUnlocked ? FMTheme.Colors.textPrimary : FMTheme.Colors.textTertiary)
            Text(definition.requirement).font(.system(size: 10)).foregroundStyle(FMTheme.Colors.textTertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(FMTheme.Spacing.sm)
        .background(FMTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
    }
}

#Preview {
    ProfileView().modelContainer(PreviewData.container)
}
