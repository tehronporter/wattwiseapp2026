import SwiftUI

enum WWTab: Int, CaseIterable {
    case practice, review, profile

    var title: String {
        switch self {
        case .practice: return "Practice"
        case .review:   return "Review"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .practice: return "list.bullet.clipboard"
        case .review:   return "chart.bar"
        case .profile:  return "person"
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab: WWTab = .practice
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    private let xpStore = XPStore.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(WWTab.allCases, id: \.self) { tab in
                NavigationStack {
                    tabContent(tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .tint(.wwBlue)
        .safeAreaInset(edge: .top, spacing: 0) {
            if appVM.isAuthenticated {
                WWStudyStatsBar(
                    streakDays: appVM.currentUser?.streakDays ?? 0,
                    totalXP: xpStore.totalXP,
                    levelProgress: xpStore.progressToNextLevel,
                    levelLabel: xpStore.levelLabel,
                    currentLevel: xpStore.currentLevel
                )
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: WWTab) -> some View {
        switch tab {
        case .practice: PracticePathView()
        case .review:   ReviewView()
        case .profile:  ProfileView()
        }
    }
}
