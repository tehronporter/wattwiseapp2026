import SwiftUI

struct TutorView: View {
    var initialContext: TutorContext? = nil
    @State private var vm = TutorViewModel()
    @State private var showClearConfirmation = false
    @State private var showNECLookup = false
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 0) {
            messagesSection
            usageLimitBanner
            WWDivider()
            TutorInputBar(
                text: $vm.inputText,
                isSending: vm.isSending,
                isDisabled: appVM.subscriptionState.tutorLimitReached
            ) {
                Task { await vm.send(services: services, subscription: appVM.subscriptionState) }
            }
        }
        .background(Color.wwBackground)
        .navigationTitle("AI Tutor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showNECLookup = true
                } label: {
                    Label("NEC", systemImage: "book.pages")
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwBlue)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !vm.messages.isEmpty {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                    .font(WWFont.body(.medium))
                    .foregroundColor(.wwTextSecondary)
                }
            }
        }
        .confirmationDialog("Clear conversation?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                withAnimation { vm.clear() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all messages in this session.")
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(reason: "Unlimited AI tutoring is a Pro feature.")
                .environment(services)
                .environment(appVM)
        }
        .navigationDestination(isPresented: $showNECLookup) {
            NECView()
                .environment(services)
                .environment(appVM)
        }
        .onAppear {
            if let ctx = initialContext {
                vm.context = ctx
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if vm.messages.isEmpty {
            TutorEmptyState(subscription: appVM.subscriptionState) { suggestion in
                vm.inputText = suggestion
                Task { await vm.send(services: services, subscription: appVM.subscriptionState) }
            } onOpenNEC: {
                showNECLookup = true
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: WWSpacing.m) {
                        ForEach(vm.messages) { message in
                            MessageBubble(message: message) { followUp in
                                vm.sendFollowUp(followUp, services: services, subscription: appVM.subscriptionState)
                            }
                            .id(message.id)
                        }
                        if vm.isSending {
                            TypingIndicator().id("typing")
                        }
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(WWFont.caption())
                                .foregroundColor(.wwError)
                                .padding(WWSpacing.s)
                        }
                    }
                    .wwScreenPadding()
                    .padding(.vertical, WWSpacing.m)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    withAnimation {
                        if vm.isSending {
                            proxy.scrollTo("typing", anchor: .bottom)
                        } else if let lastId = vm.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: vm.isSending) { _, _ in
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private var usageLimitBanner: some View {
        if !appVM.subscriptionState.isPro {
            let remaining = appVM.subscriptionState.tutorMessagesRemaining
            if remaining <= 2 {
                UsageLimitBanner(remaining: remaining, onUpgrade: { vm.showPaywall = true })
            }
        }
    }
}

// MARK: - Usage Limit Banner

private struct UsageLimitBanner: View {
    let remaining: Int
    let onUpgrade: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
            if remaining == 0 {
                Text("Daily limit reached. Upgrade to Pro.")
            } else {
                Text("\(remaining) message\(remaining == 1 ? "" : "s") remaining today.")
            }
            Spacer()
            if remaining == 0 {
                Button("Upgrade", action: onUpgrade)
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
            }
        }
        .font(WWFont.caption())
        .foregroundColor(.wwTextSecondary)
        .padding(.horizontal, WWSpacing.m)
        .padding(.vertical, WWSpacing.s)
        .background(Color.wwSurface)
    }
}

// MARK: - Empty State / Suggestions

private struct TutorEmptyState: View {
    let subscription: SubscriptionState
    let onSuggestion: (String) -> Void
    let onOpenNEC: () -> Void

    private let suggestions = [
        "Explain Ohm's Law with an example",
        "Where is GFCI protection required?",
        "What's the difference between grounding and bonding?",
        "How do I calculate wire size for a circuit?",
        "Explain NEC Article 250 in simple terms"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: WWSpacing.xl) {
                Spacer().frame(height: WWSpacing.xl)

                VStack(spacing: WWSpacing.m) {
                    ZStack {
                        Circle()
                            .fill(Color.wwBlueDim)
                            .frame(width: 72, height: 72)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.wwBlue)
                    }
                    Text("AI Tutor")
                        .wwHeading()
                    Text("Ask anything about electrical theory, the NEC, or exam topics. I'll explain it step by step.")
                        .wwBody(color: .wwTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .wwScreenPadding()

                if !subscription.isPro {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("\(subscription.tutorMessagesRemaining) free messages remaining today")
                    }
                    .font(WWFont.caption(.medium))
                    .foregroundColor(.wwTextMuted)
                }

                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text("Try asking:")
                        .wwLabel()
                        .wwScreenPadding()

                    ForEach(suggestions, id: \.self) { s in
                        Button {
                            onSuggestion(s)
                        } label: {
                            HStack {
                                Text(s)
                                    .wwBody()
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.circle")
                                    .foregroundColor(.wwBlue)
                                    .font(.system(size: 20))
                            }
                            .padding(WWSpacing.m)
                            .background(Color.wwSurface)
                            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .wwScreenPadding()
                    }

                    Button(action: onOpenNEC) {
                        HStack(spacing: WWSpacing.s) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.wwBlue)
                            Text("Open NEC Lookup")
                                .wwBody(color: .wwBlue)
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
                    .wwScreenPadding()
                }
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: TutorMessage
    let onFollowUp: (String) -> Void

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: WWSpacing.s) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                // AI avatar
                ZStack {
                    Circle().fill(Color.wwBlueDim).frame(width: 28, height: 28)
                    Image(systemName: "bolt")
                        .font(.system(size: 12))
                        .foregroundColor(.wwBlue)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: WWSpacing.s) {
                // Main content bubble
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text(message.content)
                        .wwBody(color: isUser ? .white : .wwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    // Steps (AI only)
                    if !isUser, let steps = message.steps, !steps.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: WWSpacing.s) {
                                    Text("\(i + 1).")
                                        .font(WWFont.caption(.semibold))
                                        .foregroundColor(.wwBlue)
                                        .frame(width: 16)
                                    Text(step)
                                        .wwBody()
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, WWSpacing.xs)
                    }
                }
                .padding(.horizontal, WWSpacing.m)
                .padding(.vertical, 12)
                .background(isUser ? Color.wwBlue : Color.wwSurface)
                .clipShape(
                    RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                )

                // Follow-up chips (AI only)
                if !isUser, let followUps = message.followUps, !followUps.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: WWSpacing.s) {
                            ForEach(followUps, id: \.self) { followUp in
                                Button {
                                    onFollowUp(followUp)
                                } label: {
                                    Text(followUp)
                                        .font(WWFont.caption(.medium))
                                        .foregroundColor(.wwBlue)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.wwBlueDim)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator
// Three dots each get independent @State so stagger actually works with repeatForever

private struct TypingIndicator: View {
    @State private var dot0: CGFloat = 0
    @State private var dot1: CGFloat = 0
    @State private var dot2: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: WWSpacing.s) {
            ZStack {
                Circle().fill(Color.wwBlueDim).frame(width: 28, height: 28)
                Image(systemName: "bolt")
                    .font(.system(size: 12))
                    .foregroundColor(.wwBlue)
            }

            HStack(spacing: 6) {
                bounceDot(offset: dot0)
                bounceDot(offset: dot1)
                bounceDot(offset: dot2)
            }
            .padding(.horizontal, WWSpacing.m)
            .padding(.vertical, 14)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))

            Spacer()
        }
        .onAppear {
            startBounce(binding: $dot0, delay: 0)
            startBounce(binding: $dot1, delay: 0.18)
            startBounce(binding: $dot2, delay: 0.36)
        }
    }

    private func bounceDot(offset: CGFloat) -> some View {
        Circle()
            .fill(Color.wwTextMuted)
            .frame(width: 7, height: 7)
            .offset(y: offset)
    }

    private func startBounce(binding: Binding<CGFloat>, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                binding.wrappedValue = -5
            }
        }
    }
}

// MARK: - Input Bar

private struct TutorInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let isDisabled: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: WWSpacing.s) {
            TextField("Ask a question…", text: $text, axis: .vertical)
                .font(WWFont.body())
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isDisabled)
                .padding(.horizontal, WWSpacing.m)
                .padding(.vertical, 12)
                .background(Color.wwSurface)
                .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.pill, style: .continuous))

            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(isDisabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.wwBlue.opacity(0.4)
                                    : Color.wwBlue)
                        .clipShape(Circle())
                }
            }
            .disabled(isSending || isDisabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, WWSpacing.m)
        .padding(.vertical, WWSpacing.s)
        .background(Color.wwBackground)
    }
}

#Preview {
    NavigationStack {
        TutorView()
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
