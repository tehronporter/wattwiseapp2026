import SwiftUI

struct ProfileView: View {
    @State private var vm = ProfileViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var showPaywall = false
    @State private var showEditExamSettings = false
    @State private var bookmarks = BookmarkStore.shared

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
                    ExamInfoSection(user: user) {
                        showEditExamSettings = true
                    }
                }

                // Bookmarks
                if !bookmarks.bookmarks.isEmpty {
                    BookmarksSection(bookmarks: bookmarks.bookmarks)
                        .environment(services)
                        .environment(appVM)
                }

                // Settings
                SettingsSection(vm: vm)

                // Danger Zone
                DangerSection(vm: vm)
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .refreshable {
            await refreshSubscriptionState()
        }
        .background(Color.wwBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .task(id: appVM.currentUser?.id) {
            await refreshSubscriptionState()
        }
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
            PaywallView(context: .general)
                .environment(services)
                .environment(appVM)
        }
        .sheet(isPresented: $showEditExamSettings) {
            if let user = appVM.currentUser {
                EditExamSettingsSheet(user: user)
                    .environment(services)
                    .environment(appVM)
            } else {
                NavigationStack {
                    WWEmptyState(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: "Profile unavailable",
                        message: "Please sign in again to update your exam settings."
                    )
                    .navigationTitle("Exam Settings")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private func refreshSubscriptionState() async {
        guard appVM.currentUser != nil else { return }
        if let state = try? await services.subscription.fetchState() {
            appVM.subscriptionState = state
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
                    Image(systemName: "flame")
                        .font(.system(size: 12))
                        .foregroundColor(.wwBlue)
                    Text("\(user.streakDays) day streak")
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(.wwBlue)
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
                        Text(state.accessTitle)
                            .wwSectionTitle()
                        Text(state.accessDescription)
                            .wwBody(color: .wwTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "bolt")
                        .font(.system(size: 22))
                        .foregroundColor(.wwBlue)
                }

                if state.hasPaidAccess == false {
                    Text(state.previewSummary)
                        .wwCaption(color: .wwTextSecondary)
                    WWPrimaryButton(title: "See Access Options", action: onUpgrade)
                } else if let expiresDescription = state.expiresDescription {
                    Text(expiresDescription)
                        .wwCaption(color: .wwTextSecondary)
                }
            }
        }
    }
}

// MARK: - Exam Info

private struct ExamInfoSection: View {
    let user: WWUser
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            WWSectionHeader(title: "Exam Settings")
            WWCard {
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    VStack(spacing: 0) {
                        ProfileRow(label: "Exam Type", value: user.examType.displayName)
                        WWDivider()
                        ProfileRow(label: "State", value: user.state.isEmpty ? "Not set" : user.state)
                        WWDivider()
                        ProfileRow(label: "Daily Goal", value: user.studyGoal.displayName)
                    }

                    WWGhostButton(title: "Update Exam Settings", color: .wwBlue, action: onEdit)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct EditExamSettingsSheet: View {
    let user: WWUser
    @State private var examType: ExamType
    @State private var stateCode: String
    @State private var studyGoal: StudyGoal
    @State private var examDate: Date?
    @State private var showExamDatePicker = false
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ProfileViewModel()

    init(user: WWUser) {
        self.user = user
        _examType = State(initialValue: user.examType)
        _stateCode = State(initialValue: user.state)
        _studyGoal = State(initialValue: user.studyGoal)
        _examDate = State(initialValue: user.examDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WWSpacing.l) {
                    Text("Keep your plan aligned with the exam and jurisdiction you're actually preparing for.")
                        .wwBody(color: .wwTextSecondary)

                    VStack(alignment: .leading, spacing: WWSpacing.m) {
                        Text("Exam Type")
                            .wwLabel()
                        VStack(spacing: WWSpacing.m) {
                            ForEach(ExamType.allCases) { type in
                                SelectableSettingCard(
                                    title: type.displayName,
                                    subtitle: type.description,
                                    isSelected: examType == type
                                ) {
                                    examType = type
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: WWSpacing.m) {
                        Text("State")
                            .wwLabel()
                        Picker("State", selection: $stateCode) {
                            ForEach(MockData.usStates, id: \.abbreviation) { state in
                                Text("\(state.name) (\(state.abbreviation))")
                                    .tag(state.abbreviation)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack {
                            Text("Selected")
                                .wwBody(color: .wwTextSecondary)
                            Spacer()
                            Text(stateCode.isEmpty ? "Not set" : stateCode)
                                .wwBody()
                        }
                        .padding(WWSpacing.m)
                        .background(Color.wwSurface)
                        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: WWSpacing.m) {
                        Text("Daily Goal")
                            .wwLabel()
                        VStack(spacing: WWSpacing.m) {
                            ForEach(StudyGoal.allCases) { goal in
                                SelectableSettingCard(
                                    title: goal.displayName,
                                    subtitle: "Sets your daily progress target and Home goal tracker.",
                                    isSelected: studyGoal == goal
                                ) {
                                    studyGoal = goal
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: WWSpacing.m) {
                        Text("Exam Date")
                            .wwLabel()
                        Button {
                            showExamDatePicker.toggle()
                        } label: {
                            HStack {
                                Text(examDate.map { $0.formatted(.dateTime.month().day().year()) } ?? "Not set")
                                    .wwBody(color: examDate == nil ? .wwTextMuted : .wwTextPrimary)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundColor(.wwBlue)
                            }
                            .padding(WWSpacing.m)
                            .background(Color.wwSurface)
                            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if showExamDatePicker {
                            DatePicker(
                                "Exam Date",
                                selection: Binding(
                                    get: { examDate ?? Date().addingTimeInterval(60 * 60 * 24 * 30) },
                                    set: { examDate = $0 }
                                ),
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(.wwBlue)
                        }

                        if examDate != nil {
                            Button("Clear exam date") { examDate = nil }
                                .font(WWFont.caption(.medium))
                                .foregroundColor(.wwTextMuted)
                        }
                    }

                    if let error = vm.profileUpdateErrorMessage {
                        Text(error)
                            .font(WWFont.caption(.medium))
                            .foregroundColor(.wwError)
                    }

                    WWPrimaryButton(
                        title: "Save Changes",
                        isLoading: vm.isUpdatingProfile,
                        isDisabled: stateCode.isEmpty
                    ) {
                        Task {
                            let didSave = await vm.updateProfileSettings(
                                for: user,
                                examType: examType,
                                state: stateCode,
                                goal: studyGoal,
                                examDate: examDate,
                                services: services,
                                appVM: appVM
                            )
                            if didSave {
                                dismiss()
                            }
                        }
                    }
                }
                .wwScreenPadding()
                .padding(.vertical, WWSpacing.m)
            }
            .background(Color.wwBackground)
            .navigationTitle("Exam Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwTextSecondary)
                }
            }
        }
    }
}

private struct SelectableSettingCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.m) {
                VStack(alignment: .leading, spacing: WWSpacing.xs) {
                    Text(title)
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwTextPrimary)
                    Text(subtitle)
                        .wwCaption(color: .wwTextSecondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.wwBlue : Color.wwDivider, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.wwBlue)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(WWSpacing.m)
            .background(isSelected ? Color.wwBlueDim : Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? Color.wwBlue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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
                    SettingsRow(icon: "arrow.clockwise", label: "Restore Access") {
                        Task {
                            do {
                                let state = try await services.subscription.restorePurchases()
                                appVM.subscriptionState = state
                                restoreMessage = state.restoreSuccessMessage
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
        .alert("Restore Access", isPresented: $showRestoreAlert) {
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

// MARK: - Bookmarks Section

private struct BookmarksSection: View {
    let bookmarks: [BookmarkedLesson]
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            WWSectionHeader(title: "Bookmarked Lessons")
            WWCard {
                VStack(spacing: 0) {
                    ForEach(bookmarks) { bookmark in
                        NavigationLink {
                            LessonView(lessonId: bookmark.id)
                                .environment(services)
                                .environment(appVM)
                        } label: {
                            HStack(spacing: WWSpacing.m) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.wwBlue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bookmark.title)
                                        .wwBody()
                                        .lineLimit(1)
                                    Text(bookmark.topic)
                                        .wwCaption(color: .wwTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.wwTextMuted)
                            }
                            .padding(WWSpacing.m)
                        }
                        .buttonStyle(.plain)

                        if bookmark.id != bookmarks.last?.id {
                            WWDivider().padding(.leading, WWSpacing.m)
                        }
                    }
                }
            }
        }
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
