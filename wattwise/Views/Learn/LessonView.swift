import SwiftUI

struct LessonView: View {
    let lessonId: UUID
    @State private var vm = LessonViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var showTutorSheet = false

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let lesson = vm.lesson {
                LessonContentView(lesson: lesson, vm: vm)
            } else if let error = vm.errorMessage {
                WWEmptyState(icon: "exclamationmark.triangle", title: "Error", message: error)
            }
        }
        .background(Color.wwBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(vm.lesson?.title ?? "")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTutorSheet = true
                } label: {
                    Label("Ask Tutor", systemImage: "bubble.left")
                        .font(.system(size: 15))
                        .foregroundColor(.wwBlue)
                }
            }
        }
        .sheet(isPresented: $showTutorSheet) {
            TutorSheet(context: vm.lesson.map {
                TutorContext(type: .lesson, id: $0.id, excerpt: $0.sections.first?.body)
            })
            .environment(services)
            .environment(appVM)
        }
        .sheet(isPresented: $vm.showNECSheet) {
            if let nec = vm.selectedNEC {
                NECReferenceSheet(reference: nec)
            }
        }
        .task { await vm.load(lessonId: lessonId, services: services) }
        .onDisappear { Task { await vm.saveProgress(services: services) } }
    }
}

// MARK: - Lesson Content

private struct LessonContentView: View {
    let lesson: WWLesson
    @Bindable var vm: LessonViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                // Lesson meta
                HStack(spacing: WWSpacing.m) {
                    Label(lesson.topic, systemImage: "tag")
                    Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                }
                .font(WWFont.caption(.medium))
                .foregroundColor(.wwTextMuted)

                WWDivider()

                // Content sections
                ForEach(lesson.sections) { section in
                    LessonSectionView(section: section) { necCode in
                        if let ref = lesson.necReferences.first(where: { $0.code == necCode }) {
                            vm.tapNEC(ref)
                        }
                    }
                }

                // NEC References
                if !lesson.necReferences.isEmpty {
                    VStack(alignment: .leading, spacing: WWSpacing.m) {
                        WWDivider()
                        Text("Referenced Articles")
                            .wwLabel()
                            .textCase(.uppercase)
                        ForEach(lesson.necReferences) { ref in
                            NECReferenceChip(reference: ref) {
                                vm.tapNEC(ref)
                            }
                        }
                    }
                }

                Spacer().frame(height: WWSpacing.xxxl)
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
    }
}

// MARK: - Lesson Section View

private struct LessonSectionView: View {
    let section: LessonSection
    let onNECTap: (String) -> Void

    var body: some View {
        switch section.type {
        case .heading:
            Text(section.heading ?? section.body)
                .wwSubheading()

        case .paragraph:
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                if let heading = section.heading {
                    Text(heading).wwSectionTitle()
                }
                Text(section.body)
                    .wwBodyLarge(color: .wwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }

        case .bullet:
            HStack(alignment: .top, spacing: WWSpacing.s) {
                Circle()
                    .fill(Color.wwBlue)
                    .frame(width: 5, height: 5)
                    .padding(.top, 8)
                Text(section.body)
                    .wwBody()
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .callout:
            CalloutCard(heading: section.heading, text: section.body, necCode: section.necCode, onNECTap: onNECTap)

        case .necCallout:
            CalloutCard(heading: section.heading, text: section.body, necCode: section.necCode, onNECTap: onNECTap, isNEC: true)
        }
    }
}

// MARK: - Callout Card

private struct CalloutCard: View {
    let heading: String?
    let text: String
    let necCode: String?
    let onNECTap: (String) -> Void
    var isNEC: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            if let heading {
                Text(heading)
                    .font(WWFont.body(.semibold))
                    .foregroundColor(.wwBlue)
            }
            Text(text)
                .wwBody()
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            if let necCode {
                Button {
                    onNECTap(necCode)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 12))
                        Text("NEC \(necCode)")
                            .font(WWFont.caption(.semibold))
                    }
                    .foregroundColor(.wwBlue)
                }
            }
        }
        .padding(WWSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wwBlueDim)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                .strokeBorder(Color.wwBlue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - NEC Reference Chip

private struct NECReferenceChip: View {
    let reference: NECReference
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.s) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.wwBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEC \(reference.code)")
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(.wwBlue)
                    Text(reference.title)
                        .wwCaption()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.wwTextMuted)
            }
            .padding(WWSpacing.m)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NEC Reference Sheet (modal)

struct NECReferenceSheet: View {
    let reference: NECReference
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WWSpacing.l) {
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        Text("NEC \(reference.code)")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwBlue)
                        Text(reference.title)
                            .wwHeading()
                        Text(reference.summary)
                            .wwBodyLarge(color: .wwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let expanded = reference.expanded {
                        WWDivider()
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            Text("Detailed Explanation")
                                .wwSectionTitle()
                            Text(expanded)
                                .wwBody()
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                    }
                }
                .wwScreenPadding()
                .padding(.vertical, WWSpacing.m)
            }
            .background(Color.wwBackground)
            .navigationTitle("NEC \(reference.code)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwBlue)
                }
            }
        }
    }
}

// MARK: - Tutor Sheet (embedded)

struct TutorSheet: View {
    let context: TutorContext?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TutorView(initialContext: context)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                            .font(WWFont.body(.medium))
                            .foregroundColor(.wwBlue)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        LessonView(lessonId: MockData.fundamentalsLessons[0].id)
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
