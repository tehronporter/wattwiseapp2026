import SwiftUI

struct TutorSheetView: View {
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var messages: [TutorMessage] = []
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) var dismiss

    let context: TutorContext?
    let contextTitle: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with context badge
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    HStack {
                        Text("Ask Tutor")
                            .font(WWFont.heading(.semibold))
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.wwTextSecondary)
                        }
                    }
                    if !contextTitle.isEmpty {
                        Text(contextTitle)
                            .font(WWFont.caption(.regular))
                            .foregroundColor(.wwTextSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(WWSpacing.m)
                .background(Color.wwBackground)
                .border(width: 1, edges: [.bottom], color: Color.wwDivider)

                // Message list
                if messages.isEmpty && !isLoading {
                    VStack(spacing: WWSpacing.m) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 32))
                            .foregroundColor(.wwTextMuted)
                        Text("Ask a question")
                            .font(WWFont.sectionTitle(.semibold))
                            .foregroundColor(.wwTextPrimary)
                        Text("I'm here to help you understand the material.")
                            .font(WWFont.body(.regular))
                            .foregroundColor(.wwTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(WWSpacing.l)
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: WWSpacing.m) {
                                ForEach(messages) { message in
                                    TutorMessageView(message: message)
                                        .id(message.id)
                                }
                                if isLoading {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.8, anchor: .center)
                                        Text("Tutor is thinking...")
                                            .font(WWFont.caption(.regular))
                                            .foregroundColor(.wwTextSecondary)
                                    }
                                    .padding(WWSpacing.m)
                                }
                            }
                            .padding(WWSpacing.m)
                        }
                        .onChange(of: messages.count) {
                            if let lastMessage = messages.last {
                                scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input field
                HStack(spacing: WWSpacing.s) {
                    TextField("Type your question...", text: $messageText, axis: .vertical)
                        .font(WWFont.body(.regular))
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? .wwTextMuted : .wwBlue)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding(WWSpacing.m)
                .background(Color.wwBackground)
            }
            .background(Color.wwBackground)
        }
    }

    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmedMessage.isEmpty else { return }

        // Add user message to display
        let userMessage = TutorMessage(
            id: UUID(),
            content: trimmedMessage,
            role: .user,
            timestamp: Date()
        )
        messages.append(userMessage)
        messageText = ""

        isLoading = true

        Task {
            do {
                let result = try await services.tutor.sendMessage(
                    trimmedMessage,
                    context: context,
                    history: messages,
                    sessionID: nil
                )

                await MainActor.run {
                    messages.append(result.message)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = TutorMessage(
                        id: UUID(),
                        content: "Sorry, I encountered an error. Please try again.",
                        role: .assistant,
                        timestamp: Date()
                    )
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
}

private struct TutorMessageView: View {
    let message: TutorMessage
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: WWSpacing.s) {
            if message.role == .user {
                // User message
                Text(message.content)
                    .font(WWFont.body(.regular))
                    .foregroundColor(.white)
                    .padding(WWSpacing.m)
                    .background(Color.wwBlue)
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // Assistant message
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    Text(message.content)
                        .font(WWFont.body(.regular))
                        .foregroundColor(.wwTextPrimary)

                    let steps = message.steps ?? []
                    let bullets = message.bullets ?? []
                    let references = message.references ?? []
                    let followUps = message.followUps ?? []

                    if !steps.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            Text("Steps:")
                                .font(WWFont.label(.semibold))
                                .foregroundColor(.wwTextSecondary)
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: WWSpacing.s) {
                                    Text("\(index + 1).")
                                        .font(WWFont.caption(.semibold))
                                        .foregroundColor(.wwBlue)
                                    Text(step)
                                        .font(WWFont.caption(.regular))
                                        .foregroundColor(.wwTextSecondary)
                                }
                            }
                        }
                    }

                    if !bullets.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            ForEach(bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: WWSpacing.s) {
                                    Text("•")
                                        .font(WWFont.caption(.semibold))
                                        .foregroundColor(.wwBlue)
                                    Text(bullet)
                                        .font(WWFont.caption(.regular))
                                        .foregroundColor(.wwTextSecondary)
                                }
                            }
                        }
                    }

                    if !references.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.xs) {
                            Text("References:")
                                .font(WWFont.label(.semibold))
                                .foregroundColor(.wwTextSecondary)
                            ForEach(references, id: \.self) { ref in
                                Text(ref)
                                    .font(WWFont.caption(.regular))
                                    .foregroundColor(.wwBlue)
                            }
                        }
                    }

                    if !followUps.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.xs) {
                            Text("Follow-up questions:")
                                .font(WWFont.label(.semibold))
                                .foregroundColor(.wwTextSecondary)
                            ForEach(followUps, id: \.self) { followUp in
                                Button(action: {}) {
                                    Text(followUp)
                                        .font(WWFont.caption(.regular))
                                        .foregroundColor(.wwBlue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(WWSpacing.m)
                .background(Color.wwSurface)
                .cornerRadius(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

extension View {
    fileprivate func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(
            VStack(spacing: 0) {
                if edges.contains(.top) {
                    color.frame(height: width)
                }
                Spacer()
                if edges.contains(.bottom) {
                    color.frame(height: width)
                }
            }
        )
        .overlay(
            HStack(spacing: 0) {
                if edges.contains(.leading) {
                    color.frame(width: width)
                }
                Spacer()
                if edges.contains(.trailing) {
                    color.frame(width: width)
                }
            }
        )
    }
}

#Preview {
    TutorSheetView(
        context: TutorContext(
            type: .lesson,
            id: UUID(),
            excerpt: nil,
            title: "AC vs DC Power",
            topicTags: ["Electrical Theory"],
            examType: nil,
            jurisdiction: nil,
            lesson: TutorContext.LessonPayload(
                lessonId: UUID(),
                title: "AC vs DC Power",
                excerpt: nil,
                topic: "Electrical Theory",
                necReferences: []
            ),
            quizReview: nil,
            necDetail: nil
        ),
        contextTitle: "Asking about: AC vs DC Power"
    )
    .environment(ServiceContainer())
    .environment(AppViewModel())
}
