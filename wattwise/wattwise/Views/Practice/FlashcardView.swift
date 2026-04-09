import SwiftUI

// MARK: - Flashcard Session View

struct FlashcardView: View {
    @State private var vm: FlashcardViewModel
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    init(certificationLevel: String? = nil) {
        _vm = State(initialValue: FlashcardViewModel(certificationLevel: certificationLevel))
    }

    var body: some View {
        Group {
            if vm.allCards.isEmpty {
                WWEmptyState(
                    icon: "rectangle.stack",
                    title: "No flashcards available",
                    message: "Flashcards will appear here as content is added for your exam level."
                )
            } else {
                VStack(spacing: WWSpacing.l) {
                    // Topic filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: WWSpacing.s) {
                            ForEach(FlashcardTopic.allCases) { topic in
                                Button {
                                    vm.selectTopic(topic)
                                } label: {
                                    Text(topic.rawValue)
                                        .font(WWFont.caption(.semibold))
                                        .foregroundColor(vm.selectedTopic == topic ? .white : .wwBlue)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(vm.selectedTopic == topic ? Color.wwBlue : Color.wwBlueDim)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, WWSpacing.m)
                    }
                    .padding(.horizontal, -WWSpacing.m)

                    if vm.cards.isEmpty {
                        WWEmptyState(
                            icon: "rectangle.stack",
                            title: "No cards in this topic",
                            message: "Try a different filter or tap All to see all flashcards."
                        )
                        Spacer()
                    } else {
                        // Progress
                        VStack(spacing: WWSpacing.s) {
                            HStack {
                                Text("\(vm.currentIndex + 1) of \(vm.cards.count)")
                                    .wwCaption(color: .wwTextMuted)
                                Spacer()
                                Button("Shuffle") { vm.shuffle() }
                                    .font(WWFont.caption(.medium))
                                    .foregroundColor(.wwBlue)
                            }
                            ProgressView(value: Double(vm.currentIndex + 1), total: Double(vm.cards.count))
                                .tint(.wwBlue)
                        }

                        // Card
                        FlipCardView(
                            front: vm.currentCard.front,
                            back: vm.currentCard.back,
                            necReference: vm.currentCard.necReference,
                            isFlipped: $vm.isFlipped
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)

                        // Tap hint
                        if !vm.isFlipped {
                            Text("Tap card to reveal answer")
                                .wwCaption(color: .wwTextMuted)
                        }

                        // Navigation
                        HStack(spacing: WWSpacing.m) {
                            Button {
                                vm.previous()
                            } label: {
                                Label("Previous", systemImage: "chevron.left")
                                    .font(WWFont.body(.medium))
                                    .foregroundColor(vm.currentIndex == 0 ? .wwTextMuted : .wwBlue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: WWSpacing.minTapTarget)
                                    .overlay(
                                        Capsule().strokeBorder(
                                            vm.currentIndex == 0 ? Color.wwDivider : Color.wwBlue,
                                            lineWidth: 1.5
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.currentIndex == 0)

                            if vm.isLastCard {
                                Button {
                                    vm.restart()
                                } label: {
                                    Text("Restart")
                                        .font(WWFont.body(.semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: WWSpacing.minTapTarget)
                                        .background(Color.wwSuccess)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    vm.next()
                                } label: {
                                    Label("Next", systemImage: "chevron.right")
                                        .labelStyle(.titleAndIcon)
                                        .font(WWFont.body(.medium))
                                        .foregroundColor(.wwBlue)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: WWSpacing.minTapTarget)
                                        .overlay(
                                            Capsule().strokeBorder(Color.wwBlue, lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()
                    }
                }
                .wwScreenPadding()
                .padding(.top, WWSpacing.m)
            }
        }
        .background(Color.wwBackground)
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load(services: services, appVM: appVM) }
    }
}

// MARK: - Flip Card View

private struct FlipCardView: View {
    let front: String
    let back: String
    let necReference: String
    @Binding var isFlipped: Bool
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Back face
            cardFace(text: back, label: "Answer", sublabel: "NEC \(necReference)", isFront: false)
                .opacity(rotation >= 90 ? 1 : 0)
                .rotation3DEffect(.degrees(rotation - 180), axis: (x: 0, y: 1, z: 0))

            // Front face
            cardFace(text: front, label: "Term / Concept", sublabel: nil, isFront: true)
                .opacity(rotation < 90 ? 1 : 0)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        }
        .onTapGesture { flip() }
        .onChange(of: isFlipped) { _, flipped in
            if flipped != (rotation >= 90) { flip() }
        }
    }

    private func flip() {
        withAnimation(.easeInOut(duration: 0.4)) {
            rotation = rotation < 90 ? 180 : 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isFlipped = rotation >= 90
        }
    }

    @ViewBuilder
    private func cardFace(text: String, label: String, sublabel: String?, isFront: Bool) -> some View {
        WWCard {
            VStack(spacing: WWSpacing.m) {
                Spacer()
                VStack(spacing: WWSpacing.s) {
                    Text(label)
                        .wwLabel()
                        .textCase(.uppercase)
                        .foregroundColor(isFront ? .wwBlue : .wwSuccess)
                    Text(text)
                        .wwBodyLarge()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let sublabel {
                    Text(sublabel)
                        .wwCaption(color: .wwTextMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 200)
        }
    }
}

// MARK: - Flashcard Topic

enum FlashcardTopic: String, CaseIterable, Identifiable {
    case all          = "All"
    case necTables    = "NEC Tables"
    case calculations = "Calculations"
    case theory       = "Theory"
    case safety       = "Safety"
    case codeNav      = "Code Nav"

    var id: String { rawValue }

    /// Infer topic from a NEC reference code string.
    static func inferred(from necReference: String) -> FlashcardTopic {
        let code = necReference.trimmingCharacters(in: .whitespaces)
        if code.isEmpty || code == "—" { return .theory }

        // Tables: 310.16, 314.16, 250.66, 220.42, 430.248, Chapter 9
        if code.hasPrefix("310.16") || code.hasPrefix("314.16") || code.hasPrefix("250.66")
            || code.hasPrefix("220.42") || code.hasPrefix("220.12") || code.hasPrefix("430.24")
            || code.lowercased().contains("table") || code.lowercased().contains("chapter 9") {
            return .necTables
        }
        // Safety: NFPA 70E, 90.1, 300.4
        if code.hasPrefix("90.1") || code.lowercased().contains("70e") || code.hasPrefix("300.") {
            return .safety
        }
        // Calculations: 220, 230, 310, 430
        if code.hasPrefix("220.") || code.hasPrefix("230.") || code.hasPrefix("310.")
            || code.hasPrefix("430.") || code.hasPrefix("215.") {
            return .calculations
        }
        // Code navigation / structure: 90.3, 90.4, 90.5, 100
        if code.hasPrefix("90.") || code.hasPrefix("Article 100") || code.hasPrefix("100") {
            return .codeNav
        }
        return .theory
    }
}

// MARK: - FlashcardViewModel

@Observable
final class FlashcardViewModel {
    var allCards: [FlashcardRecord] = []
    var currentIndex: Int = 0
    var isFlipped: Bool = false
    var selectedTopic: FlashcardTopic = .all
    private let certificationLevel: String?

    init(certificationLevel: String? = nil) {
        self.certificationLevel = certificationLevel
    }

    var cards: [FlashcardRecord] {
        guard selectedTopic != .all else { return allCards }
        return allCards.filter { FlashcardTopic.inferred(from: $0.necReference) == selectedTopic }
    }

    var currentCard: FlashcardRecord {
        guard !cards.isEmpty, currentIndex < cards.count else {
            return FlashcardRecord(id: "empty", front: "--", back: "--", necReference: "", certificationLevel: "")
        }
        return cards[currentIndex]
    }
    var isLastCard: Bool { cards.isEmpty || currentIndex == cards.count - 1 }

    func load(services: ServiceContainer, appVM: AppViewModel) {
        guard allCards.isEmpty else { return }
        let level = certificationLevel ?? appVM.currentUser?.examType.rawValue
        let loaded = (try? WattWiseContentRuntimeAdapter.flashcards(certificationLevel: level)) ?? []
        allCards = loaded
    }

    func selectTopic(_ topic: FlashcardTopic) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTopic = topic
            currentIndex = 0
            isFlipped = false
        }
    }

    func next() {
        guard currentIndex < cards.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            isFlipped = false
            currentIndex += 1
        }
    }

    func previous() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            isFlipped = false
            currentIndex -= 1
        }
    }

    func shuffle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            allCards.shuffle()
            currentIndex = 0
            isFlipped = false
        }
    }

    func restart() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex = 0
            isFlipped = false
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardView()
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
