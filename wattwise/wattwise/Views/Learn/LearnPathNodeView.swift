import SwiftUI

// MARK: - Learn Path Node View

/// A circular node representing a module on the winding learn path.
/// Shows completion state, topic theme color, and a pulsing animation for in-progress modules.
struct LearnPathNodeView: View {
    let module: WWModule
    let index: Int
    let theme: WWTopicTheme

    @State private var isPulsing = false

    private var nodeState: NodeState {
        if module.progress >= 1.0 { return .completed }
        if module.progress > 0    { return .inProgress }
        return .locked
    }

    private enum NodeState {
        case completed, inProgress, locked
    }

    var body: some View {
        VStack(spacing: WWSpacing.s) {
            ZStack {
                // Outer pulse ring (in-progress only)
                if nodeState == .inProgress {
                    Circle()
                        .stroke(theme.color.opacity(0.25), lineWidth: 6)
                        .frame(width: 88, height: 88)
                        .scaleEffect(isPulsing ? 1.12 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                // Base circle
                Circle()
                    .fill(theme.color.opacity(nodeState == .locked ? 0.06 : 0.14))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                nodeState == .locked ? Color.wwDivider : theme.color,
                                lineWidth: nodeState == .inProgress ? 2.5 : 2
                            )
                    )

                // Icon / lock overlay
                if nodeState == .locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.wwTextMuted)
                } else {
                    Image(systemName: theme.icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(theme.color)
                }

                // Completed badge (top-right)
                if nodeState == .completed {
                    Circle()
                        .fill(Color.wwSuccess)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 26, y: -26)
                }

                // In-progress ring badge (bottom-right arc)
                if nodeState == .inProgress {
                    Circle()
                        .trim(from: 0, to: module.progress)
                        .stroke(theme.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 90, height: 90)
            .scaleEffect(nodeState == .inProgress ? (isPulsing ? 1.03 : 1.0) : 1.0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)

            // Module title
            Text(module.title)
                .font(WWFont.caption(.semibold))
                .foregroundColor(nodeState == .locked ? .wwTextMuted : .wwTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 100)

            // Lesson count
            Text("\(module.lessonCount) lessons")
                .font(WWFont.label())
                .foregroundColor(.wwTextMuted)
        }
        .onAppear {
            if nodeState == .inProgress {
                isPulsing = true
            }
        }
    }
}
