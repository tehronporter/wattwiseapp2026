import SwiftUI

struct ProfileView: View {
    @State private var vm = ProfileViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: WWSpacing.l) {
                // User Header
                if let user = appVM.currentUser {
                    UserHeaderSection(user: user)
                }

                // Subscription Card
                SubscriptionCard(
                    state: appVM.subscriptionState,
                    onUpgrade: { showPaywall = true }
                )

                // Exam Info
                if let user = appVM.currentUser {
                    ExamInfoSection(user: user)
                }

                // Settings
                SettingsSection(vm: vm)

                // Danger Zone
                DangerSection(vm: vm)
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .alert("Sign Out?", isPresented: $vm.showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                Task { await vm.signOut(services: services, appVM: appVM) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your progress.")
        }
        .alert("Reset Progress?", isPresented: $vm.showResetAlert) {
            Button("Reset Everything", role: .destructive) {
                vm.resetProgress(services: services, appVM: appVM)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your progress, quiz history, and study data. This cannot be undone.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: "Unlock unlimited access to all features.")
                .environment(services)
                .environment(appVM)
        }
    }
}

// MARK: - User Header

private struct UserHeaderSection: View {
    let user: WWUser

    var body: some View {
        HStack(spacing: WWSpacing.m) {
            ZStack {
                Circle()
                    .fill(Color.wwBlueDim)
                    .frame(width: 60, height: 60)
                Text(user.initials)
                    .font(WWFont.heading(.bold))
                    .foregroundColor(.wwBlue)
            }
            VStack(alignment: .leading, spacing: 4) {
                if let name = user.displayName {
                    Text(name).wwSectionTitle()
                }
                Text(user.email)
                    .wwBody(color: .wwTextSecondary)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FF6B35"))
                    Text("\(user.streakDays) day streak")
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(Color(hex: "#FF6B35"))
                }
            }
            Spacer()
        }
        .padding(WWSpacing.m)
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
    }
}

extension WWUser {
    var initials: String {
        if let name = displayName, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(email.prefix(1)).uppercased()
    }
}

// MARK: - Subscription Card

private struct SubscriptionCard: View {
    let state: SubscriptionState
    let onUpgrade: () -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.isPro ? "WattWise Pro" : "WattWise Free")
                            .wwSectionTitle()
                        Text(state.isPro
                             ? "Full access · All features unlocked"
                             : "Limited access · Upgrade for full features")
                            .wwBody(color: .wwTextSecondary)
                    }
                    Spacer()
                    Image(systemName: state.isPro ? "bolt.fill" : "bolt")
                        .font(.system(size: 22))
                        .foregroundColor(.wwBlue)
                }

                if !state.isPro {
                    WWPrimaryButton(title: "Upgrade to Pro", action: onUpgrade)
                } else if let expiry = state.expiresAt {
                    Text("Renews \(expiry.formatted(.dateTime.month().day().year()))")
                        .wwCaption()
                }
            }
        }
    }
}

// MARK: - Exam Info

private struct ExamInfoSection: View {
    let user: WWUser

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            WWSectionHeader(title: "Exam Settings")
            WWCard {
                VStack(spacing: 0) {
                    ProfileRow(label: "Exam Type", value: user.examType.displayName)
                    WWDivider()
                    ProfileRow(label: "State", value: user.state.isEmpty ? "Not set" : user.state)
                    WWDivider()
                    ProfileRow(label: "Daily Goal", value: user.studyGoal.displayName)
                }
            }
        }
    }
}

private struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).wwBody()
            Spacer()
            Text(value).wwBody(color: .wwTextSecondary)
        }
        .padding(WWSpacing.m)
    }
}

// MARK: - Settings Section

private struct SettingsSection: View {
    @Bindable var vm: ProfileViewModel
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.openURL) private var openURL
    @State private var restoreMessage: String?
    @State private var showRestoreAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            WWSectionHeader(title: "Account")
            WWCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRow(icon: "arrow.clockwise", label: "Restore Purchases") {
                        Task {
                            do {
                                let state = try await services.subscription.restorePurchases()
                                appVM.subscriptionState = state
                                restoreMessage = state.isPro
                                    ? "Your Pro subscription has been restored."
                                    : "No active subscription found."
                            } catch {
                                restoreMessage = error.localizedDescription
                            }
                            showRestoreAlert = true
                        }
                    }
                    WWDivider()
                    SettingsRow(icon: "questionmark.circle", label: "Help & Support") {
                        openURL(URL(string: "mailto:support@wattwiseapp.com")!)
                    }
                    WWDivider()
                    SettingsRow(icon: "shield", label: "Privacy Policy") {
                        openURL(URL(string: "https://wattwiseapp.com/privacy")!)
                    }
                }
            }
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.wwTextSecondary)
                    .frame(width: 22)
                Text(label).wwBody()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.wwTextMuted)
            }
            .padding(WWSpacing.m)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Danger Section

private struct DangerSection: View {
    @Bindable var vm: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            WWSectionHeader(title: "Account Actions")
            VStack(spacing: WWSpacing.s) {
                WWGhostButton(title: "Reset All Progress", color: .wwError) {
                    vm.showResetAlert = true
                }
                WWGhostButton(title: "Sign Out", color: .wwTextSecondary) {
                    vm.showSignOutAlert = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(ServiceContainer())
            .environment({
                let vm = AppViewModel()
                vm.authState = .authenticated(WWUser(
                    id: UUID(),
                    email: "test@example.com",
                    displayName: "Alex",
                    examType: .apprentice,
                    state: "TX",
                    studyGoal: .moderate,
                    streakDays: 4,
                    isOnboardingComplete: true
                ))
                return vm
            }())
    }
}
