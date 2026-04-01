import SwiftUI

enum WWTab: Int, CaseIterable {
    case home, learn, practice, tutor, profile

    var title: String {
        switch self {
        case .home:     return "Home"
        case .learn:    return "Learn"
        case .practice: return "Practice"
        case .tutor:    return "Tutor"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .learn:    return "book"
        case .practice: return "list.bullet.clipboard"
        case .tutor:    return "bubble.left"
        case .profile:  return "person"
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab: WWTab = .home
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

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
    }

    @ViewBuilder
    private func tabContent(_ tab: WWTab) -> some View {
        switch tab {
        case .home:     HomeView()
        case .learn:    LearnView()
        case .practice: PracticeView()
        case .tutor:    TutorView()
        case .profile:  ProfileView()
        }
    }
}
