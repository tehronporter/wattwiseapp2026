import SwiftUI

// MARK: - Learn Path Node View

/// A circular node representing a module on the winding learn path.
/// Four visual states: locked, available, inProgress, completed.
struct LearnPathNodeView: View {
    let module: WWModule
    let index: Int
    let theme: WWTopicTheme
    var isLocked: Bool = false          // true = sequentially locked (prev not started)
    var isCurrentNode: Bool = false     // true = the active "next up" node to pulse

    @State private var isPulsing = false

    var nodeState: NodeState {
        if isLocked { return .locked }
        if module.progress >= 1.0 { return .completed }
        if module.progress > 0    { return .inProgress }
        return .available
    }

    enum NodeState {
        case locked, available, inProgress, completed
    }

    // MARK: Computed Style

    private var nodeSize: CGFloat {
        switch nodeState {
        case .inProgress: return 80
        case .available:  return 76
        case .completed:  return 74
        case .locked:     return 68
        }
    }

    private var nodeFill: Color {
        switch nodeState {
        case .locked:     return Color.wwSurface
        case .available:  return Color.wwBlueDim
        case .inProgress: return Color.wwBlue
        case .completed:  return Color.wwSuccess
        }
    }

    private var nodeBorder: Color {
        switch nodeState {
        case .locked:     return Color.wwDivider
        case .available:  return Color.wwBlue.opacity(0.5)
        case .inProgress: return Color.wwBlue
        case .completed:  return Color.wwSuccess
        }
    }

    private var nodeBorderWidth: CGFloat {
        nodeState == .inProgress ? 2.5 : 1.5
    }

    private var iconName: String {
        switch nodeState {
        case .locked:     return "lock"
        case .completed:  return "checkmark"
        default:          return theme.icon
        }
    }

    private var iconColor: Color {
        switch nodeState {
        case .locked:     return .wwTextMuted
        case .available:  return .wwBlue
        case .inProgress: return .white
        case .completed:  return .white
        }
    }

    private var iconSize: CGFloat {
        switch nodeState {
        case .locked:     return 18
        case .completed:  return 22
        case .inProgress: return 22
        case .available:  return 22
        }
    }

    private var nodeOpacity: Double {
        nodeState == .locked ? 0.45 : 1.0
    }

    // MARK: Progress badge text

    private var badgeText: String? {
        switch nodeState {
        case .completed:
            return "\(module.lessonCount)/\(module.lessonCount)"
        case .inProgress:
            let done = module.completedLessons
            return "\(done)/\(module.lessonCount)"
        case .available:
            return "\(module.lessonCount) lessons"
        case .locked:
            return "\(module.lessonCount) lessons"
        }
    }

    private var badgeForeground: Color {
        switch nodeState {
        case .completed:  return .wwSuccess
        case .inProgress: return .wwBlue
        default:          return .wwTextMuted
        }
    }

    private var badgeBackground: Color {
        switch nodeState {
        case .completed:  return Color.wwSuccess.opacity(0.12)
        case .inProgress: return Color.wwBlueDim
        default:          return Color.clear
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: WWSpacing.s) {
            ZStack {
                // Pulse ring — available or in-progress current node
                if isCurrentNode || nodeState == .inProgress {
                    Circle()
                        .stroke(Color.wwBlue.opacity(isPulsing ? 0.25 : 0.04), lineWidth: 8)
                        .frame(width: nodeSize + 16, height: nodeSize + 16)
                        .scaleEffect(isPulsing ? 1.06 : 0.96)
                        .animation(
                            .easeInOut(duration: 1.3).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                }

                // Base circle fill
                Circle()
                    .fill(nodeFill)
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay(
                        Circle()
                            .strokeBorder(nodeBorder, lineWidth: nodeBorderWidth)
                    )

                // In-progress arc overlay on top of base circle
                if nodeState == .inProgress && module.progress > 0 {
                    Circle()
                        .trim(from: 0, to: module.progress)
                        .stroke(
                            Color.white.opacity(0.4),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: nodeSize - 6, height: nodeSize - 6)
                        .rotationEffect(.degrees(-90))
                }

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: nodeState == .completed ? .bold : .regular))
                    .foregroundColor(iconColor)
            }
            .frame(width: nodeSize + 20, height: nodeSize + 20)
            .opacity(nodeOpacity)
            .onAppear {
                if nodeState == .inProgress || isCurrentNode { isPulsing = true }
            }

            // Module title
            Text(module.title)
                .font(WWFont.caption(.semibold))
                .foregroundColor(nodeState == .locked ? .wwTextMuted : .wwTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 108)

            // State badge
            if nodeState == .inProgress {
                Text("Continue →")
                    .font(WWFont.label(.semibold))
                    .foregroundColor(.wwBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.wwBlueDim)
                    .clipShape(Capsule())
            } else if let badge = badgeText {
                HStack(spacing: 3) {
                    if nodeState == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.wwSuccess)
                    }
                    Text(badge)
                        .font(WWFont.label(nodeState == .completed ? .semibold : .regular))
                        .foregroundColor(badgeForeground)
                }
                .padding(.horizontal, nodeState == .completed ? 8 : 0)
                .padding(.vertical, nodeState == .completed ? 3 : 0)
                .background(badgeBackground)
                .clipShape(Capsule())
            }
        }
    }
}
