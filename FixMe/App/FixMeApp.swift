import SwiftUI
import SwiftData

@main
struct FixMeApp: App {

    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container.appState)
                .environment(\.services, container.services)
                .modelContainer(container.modelContainer)
                .preferredColorScheme(nil)
        }
    }
}

/// Root view that switches between onboarding and the main tab experience, and hosts the
/// full-screen alarm so it can appear over any tab.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var linkResult: String?
    /// A shared-start invitation waiting to be shown. Presented as a sheet rather than
    /// applied silently — accepting changes the user's journey, so they have to say yes.
    @State private var pendingPact: PendingPact?

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
        .fullScreenCover(item: Binding(
            get: { services.alarms.ringingAlarmID.map(RingingAlarm.init) },
            set: { services.alarms.ringingAlarmID = $0?.id }
        )) { ringing in
            RingingAlarmHost(alarmID: ringing.id)
        }
        .task {
            // Pending notifications don't always survive reinstalls or system events,
            // so every launch re-registers whatever alarms are still enabled.
            await services.alarms.refreshScheduledAlarms()
            adoptUserNameForPeerIdentityIfNeeded()
        }
        // Invites and progress updates arrive as fixme:// links from any messaging app.
        .onOpenURL { url in handleIncoming(url) }
        .sheet(isPresented: Binding(
            get: { appState.showGuideOnLaunch },
            set: { appState.showGuideOnLaunch = $0 }
        )) {
            HowToUseView()
        }
        .sheet(item: $pendingPact) { pending in
            PactInviteSheet(payload: pending.payload)
        }
        .alert("Fix Me", isPresented: Binding(
            get: { linkResult != nil },
            set: { if !$0 { linkResult = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkResult ?? "")
        }
    }
}

extension RootView {
    /// Repairs installs created before onboarding asked for a name — without this they
    /// keep advertising the placeholder name to every friend they pair with.
    func adoptUserNameForPeerIdentityIfNeeded() {
        guard services.peerIdentity.displayName == PeerIdentityStore.placeholderName else { return }
        let users = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        guard let name = users.first?.name, !name.isEmpty, name != "You" else { return }
        services.peerIdentity.displayName = name
    }

    /// Parses an incoming `fixme://` link.
    ///
    /// A pairing invite adds the sender's public key; a progress update is only stored if
    /// its signature verifies against a friend already paired — so forwarding someone
    /// else's link, or editing one, gets rejected rather than trusted.
    func handleIncoming(_ url: URL) {
        let store = services.makeFriendStore(modelContext)
        do {
            switch try PeerLink.parse(url) {
            case .invite(let card):
                let friend = try store.addFriend(
                    from: card,
                    ownPeerID: services.peerIdentity.peerID,
                    nearby: false
                )
                linkResult = "\(friend.displayName) added as a friend."
                appState.selectedTab = .social
            case .update(let envelope):
                if let update = try store.receive(envelope) {
                    linkResult = "New update from \(update.friend?.displayName ?? "a friend")."
                } else {
                    linkResult = "You already had that update."
                }
                appState.selectedTab = .social
            case .pact(let payload):
                // Not applied here: it sets a start date, which is the user's decision.
                pendingPact = PendingPact(payload: payload)
            }
            Haptics.notify(.success)
        } catch {
            linkResult = (error as? LocalizedError)?.errorDescription
                ?? "That link couldn't be opened."
        }
    }
}

private struct RingingAlarm: Identifiable {
    let id: UUID
}

/// Resolves the ringing alarm from the store and wires its two actions.
private struct RingingAlarmHost: View {
    let alarmID: UUID

    @Environment(\.services) private var services
    @Query private var alarms: [HabitAlarm]

    var body: some View {
        if let alarm = alarms.first(where: { $0.id == alarmID }) {
            AlarmRingingView(alarm: alarm) {
                services.alarms.completeHabit(forAlarmID: alarmID)
                Task { await services.alarms.dismissRinging(alarmID: alarmID) }
            } onSnooze: {
                Task {
                    await services.alarms.snooze(alarmID: alarmID)
                    await services.alarms.dismissRinging(alarmID: alarmID)
                }
            }
        } else {
            // The alarm was deleted between firing and being opened.
            Color.clear.onAppear { services.alarms.ringingAlarmID = nil }
        }
    }
}
