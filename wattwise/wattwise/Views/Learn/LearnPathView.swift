import SwiftUI

// MARK: - Learn Path View

/// Duolingo-inspired winding vertical path of module nodes.
/// Nodes alternate between left-center and right-center positions.
/// A Canvas layer draws bezier curves connecting them.
struct LearnPathView: View {
    let modules: [WWModule]

    @State private var lockedPrerequisiteTitle: String? = nil

    // Node size and layout constants
    private let nodeSize: CGFloat = 90
    private let rowHeight: CGFloat = 148
    private let horizontalPad: CGFloat = 56

    /// Index of the first non-completed, non-locked module — this is the "current" node to pulse.
    private var currentNodeIndex: Int? {
        for (i, mod) in modules.enumerated() {
            let isLocked = i > 0 && modules[i - 1].progress == 0
            if !isLocked && mod.progress < 1.0 { return i }
        }
        return nil
    }

    /// Whether the segment *leaving* node at `index` is fully completed
    /// (i.e., both ends of the connector are completed modules).
    private func isConnectorCompleted(_ index: Int) -> Bool {
        guard index + 1 < modules.count else { return false }
        return modules[index].progress >= 1.0 && modules[index + 1].progress >= 1.0
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // Background connector lines
                PathConnectorCanvas(
                    count: modules.count,
                    rowHeight: rowHeight,
                    nodeSize: nodeSize,
                    horizontalPad: horizontalPad,
                    completedConnectors: (0..<max(0, modules.count - 1)).map { isConnectorCompleted($0) }
                )

                // Nodes
                VStack(spacing: 0) {
                    // Section label for the first group
                    if let first = modules.first {
                        PathSectionLabel(
                            label: WWTopicTheme.theme(for: first.topicTags).label,
                            showTopLine: false
                        )
                    }

                    ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                        let theme = WWTopicTheme.theme(for: module.topicTags)
                        let isRight = index % 2 == 0
                        let isSequentiallyLocked = index > 0 && modules[index - 1].progress == 0
                        let isCurrent = index == currentNodeIndex

                        Group {
                            if isSequentiallyLocked {
                                Button {
                                    lockedPrerequisiteTitle = modules[index - 1].title
                                } label: {
                                    HStack(spacing: 0) {
                                        if isRight { Spacer() }
                                        LearnPathNodeView(
                                            module: module,
                                            index: index + 1,
                                            theme: theme,
                                            isLocked: true,
                                            isCurrentNode: false
                                        )
                                        .padding(.horizontal, horizontalPad)
                                        if !isRight { Spacer() }
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    ModuleDetailView(module: module)
                                } label: {
                                    HStack(spacing: 0) {
                                        if isRight { Spacer() }
                                        LearnPathNodeView(
                                            module: module,
                                            index: index + 1,
                                            theme: theme,
                                            isLocked: false,
                                            isCurrentNode: isCurrent
                                        )
                                        .padding(.horizontal, horizontalPad)
                                        if !isRight { Spacer() }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(height: rowHeight)

                        // Section label between topic groups
                        if let nextModule = modules[safe: index + 1] {
                            let nextTheme = WWTopicTheme.theme(for: nextModule.topicTags)
                            if nextTheme.label != theme.label {
                                PathSectionLabel(label: nextTheme.label, showTopLine: true)
                            }
                        }
                    }

                    Spacer().frame(height: WWSpacing.xxxl)
                }
            }
        }
        .alert(
            "Module Locked",
            isPresented: Binding(
                get: { lockedPrerequisiteTitle != nil },
                set: { if !$0 { lockedPrerequisiteTitle = nil } }
            )
        ) {
            Button("OK", role: .cancel) { lockedPrerequisiteTitle = nil }
        } message: {
            Text("Start \"\(lockedPrerequisiteTitle ?? "")\" first to unlock this module.")
        }
    }
}

// MARK: - Path Connector Canvas

/// Draws bezier curves connecting node centers in the alternating winding pattern.
/// Completed segments render in wwSuccess color; pending segments in wwDivider.
private struct PathConnectorCanvas: View {
    let count: Int
    let rowHeight: CGFloat
    let nodeSize: CGFloat
    let horizontalPad: CGFloat
    var completedConnectors: [Bool] = []

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard count > 1 else { return }

                let width = size.width
                let nodeCenterOffset = nodeSize / 2 + horizontalPad

                var prevCenter: CGPoint? = nil

                for i in 0..<count {
                    let isRight = i % 2 == 0
                    let x: CGFloat = isRight
                        ? width - nodeCenterOffset
                        : nodeCenterOffset
                    let y: CGFloat = CGFloat(i) * rowHeight + rowHeight / 2
                    let center = CGPoint(x: x, y: y)

                    if let prev = prevCenter {
                        var segment = Path()
                        let midY = (prev.y + center.y) / 2
                        segment.move(to: prev)
                        segment.addCurve(
                            to: center,
                            control1: CGPoint(x: prev.x, y: midY),
                            control2: CGPoint(x: center.x, y: midY)
                        )

                        let connectorIndex = i - 1
                        let isCompleted = connectorIndex < completedConnectors.count
                            ? completedConnectors[connectorIndex]
                            : false

                        context.stroke(
                            segment,
                            with: .color(isCompleted ? Color.wwSuccess.opacity(0.55) : Color.wwDivider),
                            style: StrokeStyle(
                                lineWidth: isCompleted ? 3.5 : 3,
                                lineCap: .round,
                                dash: [8, 6]
                            )
                        )
                    }
                    prevCenter = center
                }
            }
        }
    }
}

// MARK: - Section Label

private struct PathSectionLabel: View {
    let label: String
    var showTopLine: Bool = true

    var body: some View {
        VStack(spacing: WWSpacing.s) {
            if showTopLine {
                Rectangle()
                    .fill(Color.wwDivider)
                    .frame(height: 1)
                    .padding(.horizontal, WWSpacing.xl)
            }
            HStack(spacing: WWSpacing.m) {
                Rectangle().fill(Color.wwDivider).frame(height: 1)
                Text(label.uppercased())
                    .font(WWFont.label(.semibold))
                    .foregroundColor(.wwTextMuted)
                    .tracking(0.5)
                    .fixedSize()
                    .lineLimit(1)
                Rectangle().fill(Color.wwDivider).frame(height: 1)
            }
            .padding(.horizontal, WWSpacing.xl)
        }
        .padding(.vertical, WWSpacing.s)
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LearnPathView(modules: [])
            .navigationTitle("Learn")
            .background(Color.wwBackground)
    }
}
