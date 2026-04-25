import SwiftUI

// MARK: - Practice Path View (Primary Practice Tab)

struct PracticePathView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(ServiceContainer.self) private var services
    @State private var path: PracticePath?
    @State private var launchNode: PracticeNode?
    @State private var showPaywall = false
    @State private var greeting = Self.buildGreeting()
    private let xpStore = XPStore.shared

    private var user: WWUser? { appVM.currentUser }
    private var examType: ExamType { user?.examType ?? .apprentice }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                PathHeaderSection(
                    user: user,
                    greeting: greeting,
                    xpStore: xpStore,
                    path: path
                )

                if let next = path?.nextActionNode {
                    QuickStartCard(node: next, hasPaidAccess: appVM.subscriptionState.hasPaidAccess) {
                        launchNode = next
                    }
                }

                if let path {
                    ForEach(path.units) { unit in
                        PathUnitSection(unit: unit, hasPaidAccess: appVM.subscriptionState.hasPaidAccess) { node in
                            handleNodeTap(node)
                        }
                    }
                } else {
                    ForEach(0..<3, id: \.self) { _ in
                        PathSkeletonCard()
                    }
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    QuizHistoryView()
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 15))
                        .foregroundColor(.wwBlue)
                }
            }
        }
        .navigationDestination(item: $launchNode) { node in
            QuizContainerView(
                quizType: node.quizType,
                topicTags: node.topicTags
            ) { result in
                PathProgressStore.shared.save(nodeId: node.id, score: result.score)
                reloadPath()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .practiceExamLocked)
                .environment(services)
                .environment(appVM)
        }
        .onAppear { reloadPath() }
    }

    private func handleNodeTap(_ node: PracticeNode) {
        if node.isCheckpoint && !appVM.subscriptionState.hasPaidAccess {
            showPaywall = true
        } else {
            launchNode = node
        }
    }

    private func reloadPath() {
        let base = PracticePath.forExamType(examType)
        path = PathProgressStore.shared.applyProgress(to: base)
    }

    private static func buildGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }
}

// MARK: - Path Header

private struct PathHeaderSection: View {
    let user: WWUser?
    let greeting: String
    let xpStore: XPStore
    let path: PracticePath?

    private var displayName: String {
        guard let user else { return "Electrician" }
        return user.displayName ?? user.email.components(separatedBy: "@").first?.capitalized ?? "Electrician"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            // Greeting
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .wwCaption(color: .wwTextSecondary)
                Text(displayName)
                    .wwHeading()
            }

            // Stats row
            HStack(spacing: WWSpacing.m) {
                StatPill(
                    icon: "flame.fill",
                    value: "\(user?.streakDays ?? 0)",
                    label: "day streak"
                )
                StatPill(
                    icon: "bolt.fill",
                    value: xpStore.totalXP >= 1000
                        ? String(format: "%.1fk", Double(xpStore.totalXP) / 1000)
                        : "\(xpStore.totalXP)",
                    label: "total XP"
                )
                if let path {
                    StatPill(
                        icon: "checkmark.circle",
                        value: "\(path.passedCount)/\(path.totalCount)",
                        label: "nodes done"
                    )
                }
                Spacer()
                // Exam type badge
                if let user {
                    Text(user.examType.displayName)
                        .font(WWFont.label(.semibold))
                        .foregroundColor(.wwBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.wwBlueDim)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.wwBlue)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(WWFont.caption(.bold))
                    .foregroundColor(.wwTextPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.wwTextMuted)
            }
        }
    }
}

// MARK: - Quick Start Card

private struct QuickStartCard: View {
    let node: PracticeNode
    let hasPaidAccess: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WWCard {
                HStack(spacing: WWSpacing.m) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.wwBlue)
                            .frame(width: 44, height: 44)
                        Image(systemName: node.isCheckpoint ? "flag.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Up Next")
                            .font(WWFont.label(.semibold))
                            .foregroundColor(.wwBlue)
                            .textCase(.uppercase)
                        Text(node.title)
                            .wwSectionTitle()
                        Text("\(node.questionCount) questions · ~\(node.estimatedMinutes) min")
                            .wwCaption(color: .wwTextMuted)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.wwBlue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Path Unit Section

private struct PathUnitSection: View {
    let unit: PracticeUnit
    let hasPaidAccess: Bool
    let onNodeTap: (PracticeNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            // Unit header
            HStack(spacing: WWSpacing.s) {
                Text(unit.title.uppercased())
                    .font(WWFont.label(.semibold))
                    .foregroundColor(.wwTextMuted)
                Spacer()
                if unit.passedCount > 0 {
                    Text("\(unit.passedCount)/\(unit.totalCount)")
                        .font(WWFont.label(.medium))
                        .foregroundColor(unit.passedCount == unit.totalCount ? .wwSuccess : .wwBlue)
                }
            }

            VStack(spacing: WWSpacing.s) {
                ForEach(unit.nodes) { node in
                    if node.isCheckpoint {
                        CheckpointNodeCard(node: node, hasPaidAccess: hasPaidAccess) {
                            onNodeTap(node)
                        }
                    } else {
                        RegularNodeCard(node: node) {
                            onNodeTap(node)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Regular Node Card

private struct RegularNodeCard: View {
    let node: PracticeNode
    let action: () -> Void

    private var isLocked: Bool {
        node.status == .locked
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.m) {
                // Status icon
                NodeStatusIcon(status: node.status, isCheckpoint: false)

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .wwBody()
                        .foregroundColor(isLocked ? .wwTextMuted : .wwTextPrimary)
                    Text(node.subtitle)
                        .wwCaption(color: .wwTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: WWSpacing.s) {
                        Text("\(node.questionCount)q · ~\(node.estimatedMinutes)m")
                            .font(.system(size: 11))
                            .foregroundColor(.wwTextMuted)
                        if let score = node.status.bestScore {
                            Text("\(Int(score * 100))% best")
                                .font(WWFont.label(.semibold))
                                .foregroundColor(node.status.isPassed ? .wwSuccess : .wwWarning)
                        }
                    }
                }

                Spacer()

                if !isLocked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.wwTextMuted)
                }
            }
            .padding(WWSpacing.m)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.55 : 1.0)
    }

    private var borderColor: Color {
        switch node.status {
        case .completed:      return Color.wwSuccess.opacity(0.4)
        case .masteryNeeded:  return Color.wwWarning.opacity(0.4)
        case .available:      return Color.wwBlue.opacity(0.2)
        case .locked:         return Color.clear
        }
    }
}

// MARK: - Checkpoint Node Card

private struct CheckpointNodeCard: View {
    let node: PracticeNode
    let hasPaidAccess: Bool
    let action: () -> Void

    private var isLocked: Bool { node.status == .locked }
    private var locked: Bool { isLocked || !hasPaidAccess }

    var body: some View {
        Button(action: action) {
            WWCard {
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    HStack(spacing: WWSpacing.s) {
                        NodeStatusIcon(status: node.status, isCheckpoint: true)
                        Text("CHECKPOINT")
                            .font(WWFont.label(.bold))
                            .foregroundColor(locked ? .wwTextMuted : .wwBlue)
                            .textCase(.uppercase)
                        Spacer()
                        if !hasPaidAccess {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.wwTextMuted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title)
                            .wwSectionTitle()
                            .foregroundColor(locked ? .wwTextMuted : .wwTextPrimary)
                        Text(node.subtitle)
                            .wwBody(color: .wwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let score = node.status.bestScore {
                        HStack(spacing: WWSpacing.s) {
                            Image(systemName: node.status.isPassed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(node.status.isPassed ? .wwSuccess : .wwWarning)
                            Text("Best score: \(Int(score * 100))%")
                                .font(WWFont.caption(.semibold))
                                .foregroundColor(node.status.isPassed ? .wwSuccess : .wwWarning)
                        }
                    } else if !locked {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.wwBlue)
                            Text("Start exam simulation")
                                .font(WWFont.caption(.semibold))
                                .foregroundColor(.wwBlue)
                        }
                    } else if !hasPaidAccess {
                        Text("Full access required to take exam simulations.")
                            .wwCaption(color: .wwTextMuted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.6 : 1.0)
    }
}

// MARK: - Node Status Icon

private struct NodeStatusIcon: View {
    let status: QuizNodeStatus
    let isCheckpoint: Bool

    private var iconName: String {
        switch status {
        case .locked:         return "lock.fill"
        case .available:      return isCheckpoint ? "flag.fill" : "circle"
        case .completed:      return "checkmark.circle.fill"
        case .masteryNeeded:  return "exclamationmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .locked:         return .wwTextMuted
        case .available:      return isCheckpoint ? .wwBlue : .wwBlue
        case .completed:      return .wwSuccess
        case .masteryNeeded:  return .wwWarning
        }
    }

    private var size: CGFloat { isCheckpoint ? 20 : 18 }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(iconColor)
            .frame(width: 24, height: 24)
    }
}

// MARK: - Skeleton Card

private struct PathSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            RoundedRectangle(cornerRadius: 4).fill(Color.wwDivider).frame(width: 100, height: 10)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.wwSurface)
                    .frame(height: 72)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PracticePathView()
            .environment(ServiceContainer())
            .environment({
                let vm = AppViewModel()
                vm.authState = .authenticated(WWUser(
                    id: UUID(), email: "test@example.com", displayName: "Alex",
                    examType: .journeyman, state: "TX", studyGoal: .moderate,
                    streakDays: 5, isOnboardingComplete: true
                ))
                return vm
            }())
    }
}
