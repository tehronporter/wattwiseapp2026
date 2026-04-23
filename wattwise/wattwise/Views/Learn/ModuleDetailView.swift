import SwiftUI

struct ModuleDetailView: View {
    let module: WWModule
    @Environment(AppViewModel.self) private var appVM
    @Environment(ServiceContainer.self) private var services
    @State private var showPaywall = false

    private var previewLessonID: UUID? {
        module.lessons.first(where: { $0.isPreviewIncluded == true })?.id
            ?? (try? WattWiseContentRuntimeAdapter.previewLessonID(includeDraftContent: false))
    }

    private func isLocked(_ lesson: WWLesson) -> Bool {
        guard appVM.subscriptionState.hasPaidAccess == false else { return false }
        if let locked = lesson.isLocked {
            return locked
        }
        return lesson.id != previewLessonID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                WWCard {
                    VStack(alignment: .leading, spacing: WWSpacing.m) {
                        Text(module.title)
                            .wwHeading()

                        Text(module.description)
                            .wwBody(color: .wwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: WWSpacing.m) {
                            StatPill(icon: "list.bullet", value: "\(module.lessonCount) lessons")
                            StatPill(icon: "clock", value: "\(module.estimatedMinutes) min")
                            if module.progress > 0 {
                                StatPill(icon: "chart.line.uptrend.xyaxis",
                                         value: "\(Int(module.progress * 100))%",
                                         color: .wwBlue)
                            }
                        }

                        if module.progress > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Module Progress")
                                    .wwLabel()
                                WWProgressBar(value: module.progress, height: 6)
                            }
                        }
                    }
                }
                .wwScreenPadding()

                WWDivider()

                // Lessons
                VStack(alignment: .leading, spacing: 0) {
                    Text("Lessons")
                        .wwSectionTitle()
                        .wwScreenPadding()
                        .padding(.bottom, WWSpacing.s)

                    ForEach(Array(module.lessons.enumerated()), id: \.element.id) { index, lesson in
                        if isLocked(lesson) {
                            Button {
                                showPaywall = true
                            } label: {
                                LessonRow(
                                    index: index + 1,
                                    lesson: lesson,
                                    isLocked: true,
                                    isPreviewLesson: false
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                LessonView(lessonId: lesson.id)
                            } label: {
                                LessonRow(
                                    index: index + 1,
                                    lesson: lesson,
                                    isLocked: false,
                                    isPreviewLesson: appVM.subscriptionState.hasPaidAccess == false && (lesson.isPreviewIncluded == true || lesson.id == previewLessonID)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if index < module.lessons.count - 1 {
                            WWDivider().padding(.leading, 56).wwScreenPadding()
                        }
                    }
                }

                if appVM.subscriptionState.hasPaidAccess == false {
                    WWCard {
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            Text("Preview limit")
                                .wwLabel()
                                .textCase(.uppercase)
                            Text("Preview includes your first full lesson. Keep going with Fast Track or Full Prep to open the rest of the curriculum.")
                                .wwBody(color: .wwTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .wwScreenPadding()
                }
            }
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .lessonLocked)
                .environment(services)
                .environment(appVM)
        }
    }
}

// MARK: - Lesson Row

private struct LessonRow: View {
    let index: Int
    let lesson: WWLesson
    let isLocked: Bool
    let isPreviewLesson: Bool

    private var statusIcon: String {
        switch lesson.status {
        case .completed:  return "checkmark.circle"
        case .inProgress: return "circle"
        case .notStarted: return "circle"
        }
    }

    private var statusColor: Color {
        switch lesson.status {
        case .completed:  return .wwSuccess
        case .inProgress: return .wwBlue
        case .notStarted: return .wwDivider
        }
    }

    var body: some View {
        HStack(spacing: WWSpacing.m) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 22))
                .foregroundColor(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: WWSpacing.s) {
                    Text(lesson.title)
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if isPreviewLesson {
                        Text("Preview")
                            .wwLabel(color: .wwBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.wwBlueDim)
                            .clipShape(Capsule())
                    }
                    if isLocked {
                        Image(systemName: "lock")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.wwTextMuted)
                    }
                }
                HStack(spacing: WWSpacing.s) {
                    Text(lesson.topic)
                        .wwCaption()
                    Text("·")
                        .wwCaption()
                    Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                        .wwCaption()
                }
                if isLocked {
                    Text("Locked in preview")
                        .wwCaption(color: .wwTextMuted)
                }
            }

            Spacer()

            if lesson.status == .inProgress {
                Text("\(Int(lesson.completionPercentage * 100))%")
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
            }

            Image(systemName: isLocked ? "lock" : "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.wwTextMuted)
        }
        .padding(.vertical, WWSpacing.m)
        .wwScreenPadding()
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let value: String
    var color: Color = .wwTextMuted

    var body: some View {
        Label(value, systemImage: icon)
            .font(WWFont.caption(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        ModuleDetailView(module: ((try? WattWiseContentRuntimeAdapter.loadModules(includeDraftContent: true))?.first) ?? WWModule(
            id: UUID(),
            title: "Preview Module",
            description: "Preview data unavailable.",
            lessonCount: 0,
            estimatedMinutes: 0,
            topicTags: [],
            progress: 0,
            lessons: [],
            examType: nil,
            publishStatus: nil,
            freshnessStatus: nil,
            jurisdictionScope: nil,
            lastVerifiedAt: nil
        ))
    }
}
