import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            ForEach(MainTab.allCases) { tab in
                destination(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.symbol)
                    }
                    .tag(tab)
            }
        }
        .tint(FMTheme.Colors.accent)
    }

    @ViewBuilder
    private func destination(for tab: MainTab) -> some View {
        switch tab {
        case .today: TodayView()
        case .journey: JourneyView()
        case .explore: ExploreView()
        case .social: SocialView()
        case .profile: ProfileView()
        }
    }
}
