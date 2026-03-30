import SwiftUI

enum WWTab: Int, CaseIterable {
    case home, learn, practice, nec, profile

    var title: String {
        switch self {
        case .home:     return "Home"
        case .learn:    return "Learn"
        case .practice: return "Practice"
        case .nec:      return "NEC"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .learn:    return "book"
        case .practice: return "list.bullet.clipboard"
        case .nec:      return "book.pages"
        case .profile:  return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home:     return "house.fill"
        case .learn:    return "book.fill"
        case .practice: return "list.bullet.clipboard.fill"
        case .nec:      return "book.pages.fill"
        case .profile:  return "person.fill"
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
                    Label(tab.title, systemImage: selectedTab == tab ? tab.selectedIcon : tab.icon)
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
        case .nec:      NECView()
        case .profile:  ProfileView()
        }
    }
}
