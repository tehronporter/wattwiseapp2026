import SwiftUI

// MARK: - Learn Path View

/// Duolingo-inspired winding vertical path of module nodes.
/// Nodes alternate between left-center and right-center positions.
/// A Canvas layer draws bezier curves connecting them.
struct LearnPathView: View {
    let modules: [WWModule]

    // Node size and layout constants
    private let nodeSize: CGFloat = 90
    private let rowHeight: CGFloat = 140
    private let horizontalPad: CGFloat = 60

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // Background connector lines
                PathConnectorCanvas(
                    count: modules.count,
                    rowHeight: rowHeight,
                    nodeSize: nodeSize,
                    horizontalPad: horizontalPad
                )

                // Nodes
                VStack(spacing: 0) {
                    ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                        let theme = WWTopicTheme.theme(for: module.topicTags)
                        let isRight = index % 2 == 0

                        NavigationLink {
                            ModuleDetailView(module: module)
                        } label: {
                            HStack(spacing: 0) {
                                if isRight { Spacer() }
                                LearnPathNodeView(module: module, index: index + 1, theme: theme)
                                    .padding(.horizontal, horizontalPad)
                                if !isRight { Spacer() }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(height: rowHeight)

                        // Section break label between topic groups
                        if let nextModule = modules[safe: index + 1] {
                            let nextTheme = WWTopicTheme.theme(for: nextModule.topicTags)
                            if nextTheme.color != theme.color {
                                PathSectionDivider()
                            }
                        }
                    }

                    Spacer().frame(height: WWSpacing.xxxl)
                }
            }
        }
    }
}

// MARK: - Path Connector Canvas

/// Draws bezier curves connecting node centers in the alternating winding pattern.
private struct PathConnectorCanvas: View {
    let count: Int
    let rowHeight: CGFloat
    let nodeSize: CGFloat
    let horizontalPad: CGFloat

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard count > 1 else { return }

                let width = size.width
                let nodeCenterOffset = nodeSize / 2 + horizontalPad

                var path = Path()
                var prevCenter: CGPoint? = nil

                for i in 0..<count {
                    let isRight = i % 2 == 0
                    let x: CGFloat = isRight
                        ? width - nodeCenterOffset
                        : nodeCenterOffset
                    let y: CGFloat = CGFloat(i) * rowHeight + rowHeight / 2

                    let center = CGPoint(x: x, y: y)

                    if let prev = prevCenter {
                        // Cubic bezier: control points create the S-curve
                        let midY = (prev.y + center.y) / 2
                        path.move(to: prev)
                        path.addCurve(
                            to: center,
                            control1: CGPoint(x: prev.x, y: midY),
                            control2: CGPoint(x: center.x, y: midY)
                        )
                    }
                    prevCenter = center
                }

                context.stroke(
                    path,
                    with: .color(Color.wwDivider),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6])
                )
            }
        }
    }
}

// MARK: - Section Divider

private struct PathSectionDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.wwDivider)
                .frame(height: 1)
        }
        .padding(.horizontal, WWSpacing.xl)
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
