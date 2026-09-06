import Foundation
import SwiftData
import SwiftUI

/// Bundles the app's cross-cutting services for dependency injection via the SwiftUI environment.
/// Reference type so `HealthKitManager`'s @Observable state is shared, not copied.
@MainActor
final class ServiceContainer {
    let healthKit = HealthKitManager()
    let notifications = NotificationManager()
    /// Real on-device Vision analysis. `MockAIProvider` must never be the shipping
    /// default — it invents a confidence score without looking at the photo.
    let verification: HabitVerificationService =
        AIHabitVerificationService(provider: VisionAIProvider())
    let analytics: AnalyticsService = ConsoleAnalyticsService()
    let subscriptions: SubscriptionService
    let premium: PremiumGate
    let alarms = AlarmCoordinator()
    let peerIdentity = PeerIdentityStore()
    let nearby = NearbyPeerService()

    /// Same per-context construction as `makeSocial` — friends are stored alongside the
    /// rest of the user's data, so reads and writes must share a `ModelContext`.
    var makeFriendStore: @MainActor (ModelContext) -> FriendStore = { FriendStore(modelContext: $0) }

    /// Built per-`ModelContext` so a view's `@Query` reads and its writes always share the
    /// same context. Swapping in a networked implementation later is a one-line change here.
    var makeSocial: @MainActor (ModelContext) -> SocialService = { LocalSocialService(modelContext: $0) }

    init() {
        let subscriptions = SubscriptionService()
        self.subscriptions = subscriptions
        let premium = PremiumGate(subscriptions: subscriptions)
        self.premium = premium

        // Pairing is what earns the free week the referral screen promises, and every
        // pairing path — Nearby and invite link alike — funnels through FriendStore.
        makeFriendStore = { context in
            FriendStore(modelContext: context) { peerID in
                premium.grantReferralWeek(forPeerID: peerID)
            }
        }
    }
}

private struct ServicesEnvironmentKey: EnvironmentKey {
    /// `EnvironmentKey` demands a nonisolated default, but `ServiceContainer` is
    /// main-actor bound. This static is only ever touched while rendering (main actor),
    /// and `assumeIsolated` turns a violation of that into an immediate trap instead of
    /// a silent data race. The real container is injected by `FixMeApp`; this is the
    /// preview/fallback path.
    static let defaultValue: ServiceContainer =
        MainActor.assumeIsolated { ServiceContainer() }
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServicesEnvironmentKey.self] }
        set { self[ServicesEnvironmentKey.self] = newValue }
    }
}

/// Top-level composition root, created once in `FixMeApp`.
@MainActor
struct AppContainer {
    let modelContainer: ModelContainer
    let appState: AppState
    let services: ServiceContainer

    init() {
        self.modelContainer = PersistenceController.makeContainer()
        if DemoDataSeeder.isRequested {
            DemoDataSeeder.seed(into: modelContainer)
        }
        self.appState = AppState()
        self.services = ServiceContainer()
        // Becomes the notification delegate and registers the Done/Snooze actions.
        self.services.alarms.attach(container: modelContainer)
    }
}
