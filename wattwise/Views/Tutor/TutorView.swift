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
                vm.send(services: services, appVM: appVM)
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
            PaywallView(context: .tutorLimit)
                .environment(services)
                .environment(appVM)
        }
        .navigationDestination(isPresented: $showNECLookup) {
            NECView()
                .environment(services)
                .environment(appVM)
        }
        .onAppear {
            vm.configure(initialContext: initialContext, user: appVM.currentUser)
        }
        .onDisappear { vm.cancelPendingRequest() }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if vm.messages.isEmpty {
            TutorEmptyState(context: vm.context, subscription: appVM.subscriptionState) { suggestion in
                vm.inputText = suggestion
                vm.send(services: services, appVM: appVM)
            } onOpenNEC: {
                showNECLookup = true
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: WWSpacing.m) {
                        if vm.hasContextHeader {
                            TutorContextHeader(context: vm.context)
                        }
                        ForEach(vm.messages) { message in
                            MessageBubble(message: message) { followUp in
                                vm.sendFollowUp(followUp, services: services, appVM: appVM)
                            }
                            .id(message.id)
                        }
                        if vm.isSending {
                            TypingIndicator().id("typing")
                        }
                        if let errorState = vm.errorState {
                            TutorErrorCard(
                                errorState: errorState,
                                onPrimaryAction: {
                                    if errorState.isQuotaRelated {
                                        vm.showPaywall = true
                                    } else {
                                        vm.retry(services: services, appVM: appVM)
                                    }
                                }
                            )
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
        if appVM.subscriptionState.hasPaidAccess == false {
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
                Text("Preview tutor questions used. Choose full access for more help.")
            } else {
                Text("\(remaining) tutor question\(remaining == 1 ? "" : "s") left in preview.")
            }
            Spacer()
            if remaining == 0 {
                Button("See Options", action: onUpgrade)
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
    let context: TutorContext
    let subscription: SubscriptionState
    let onSuggestion: (String) -> Void
    let onOpenNEC: () -> Void

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
                    Text(context.sourceEyebrow ?? "AI Tutor")
                        .wwLabel()
                        .textCase(.uppercase)
                    Text(context.sourceTitle ?? "AI Tutor")
                        .wwHeading()
                    Text(
                        context.sourceSummary
                        ?? "Ask anything about electrical theory, the NEC, or exam topics. I'll keep it structured, calm, and exam-focused."
                    )
                        .wwBody(color: .wwTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .wwScreenPadding()

                if subscription.hasPaidAccess == false {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("\(subscription.tutorMessagesRemaining) tutor question\(subscription.tutorMessagesRemaining == 1 ? "" : "s") left in preview")
                    }
                    .font(WWFont.caption(.medium))
                    .foregroundColor(.wwTextMuted)
                }

                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text(context.type == .general ? "Try asking:" : "Start with:")
                        .wwLabel()
                        .wwScreenPadding()

                    ForEach(context.starterPrompts, id: \.self) { s in
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

private struct TutorContextHeader: View {
    let context: TutorContext

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                if let eyebrow = context.sourceEyebrow {
                    Text(eyebrow)
                        .wwLabel(color: .wwBlue)
                        .textCase(.uppercase)
                }
                if let title = context.sourceTitle {
                    Text(title)
                        .wwSectionTitle()
                }
                if let summary = context.sourceSummary {
                    Text(summary)
                        .wwBody(color: .wwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct TutorErrorCard: View {
    let errorState: TutorErrorState
    let onPrimaryAction: () -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                Text(errorState.title)
                    .font(WWFont.body(.semibold))
                    .foregroundColor(.wwError)
                Text(errorState.message)
                    .wwBody(color: .wwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(errorState.primaryActionTitle, action: onPrimaryAction)
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
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

                    if !isUser, let bullets = message.bullets, !bullets.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            ForEach(bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: WWSpacing.s) {
                                    Circle()
                                        .fill(Color.wwBlue)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 8)
                                    Text(bullet)
                                        .wwBody()
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    if !isUser, let references = message.references, !references.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.xs) {
                            Text("References")
                                .font(WWFont.caption(.semibold))
                                .foregroundColor(.wwTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: WWSpacing.s) {
                                    ForEach(references, id: \.self) { reference in
                                        Text(reference)
                                            .font(WWFont.caption(.medium))
                                            .foregroundColor(.wwBlue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.wwBlueDim)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
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
