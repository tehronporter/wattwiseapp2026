import SwiftUI

struct ModuleDetailView: View {
    let module: WWModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                // Module header
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    Text(module.description)
                        .wwBody(color: .wwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: WWSpacing.m) {
                        StatPill(icon: "list.bullet", value: "\(module.lessonCount) lessons")
                        StatPill(icon: "clock", value: "\(module.estimatedMinutes) min")
                        if module.progress > 0 {
                            StatPill(icon: "checkmark.circle",
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
                .wwScreenPadding()

                WWDivider()

                // Lessons
                VStack(alignment: .leading, spacing: 0) {
                    Text("Lessons")
                        .wwSectionTitle()
                        .wwScreenPadding()
                        .padding(.bottom, WWSpacing.s)

                    ForEach(Array(module.lessons.enumerated()), id: \.element.id) { index, lesson in
                        NavigationLink {
                            LessonView(lessonId: lesson.id)
                        } label: {
                            LessonRow(index: index + 1, lesson: lesson)
                        }
                        .buttonStyle(.plain)

                        if index < module.lessons.count - 1 {
                            WWDivider().padding(.leading, 56).wwScreenPadding()
                        }
                    }
                }
            }
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lesson Row

private struct LessonRow: View {
    let index: Int
    let lesson: WWLesson

    private var statusIcon: String {
        switch lesson.status {
        case .completed:  return "checkmark.circle.fill"
        case .inProgress: return "circle.lefthalf.filled"
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
                Text(lesson.title)
                    .font(WWFont.body(.medium))
                    .foregroundColor(.wwTextPrimary)
                HStack(spacing: WWSpacing.s) {
                    Text(lesson.topic)
                        .wwCaption()
                    Text("·")
                        .wwCaption()
                    Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                        .wwCaption()
                }
            }

            Spacer()

            if lesson.status == .inProgress {
                Text("\(Int(lesson.completionPercentage * 100))%")
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
            }

            Image(systemName: "chevron.right")
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
        ModuleDetailView(module: MockData.modules[0])
    }
}
