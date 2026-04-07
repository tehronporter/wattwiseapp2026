import SwiftUI

// MARK: - Base Card Container

struct WWCard<Content: View>: View {
    var padding: CGFloat = WWSpacing.m
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
    }
}

// MARK: - Progress Bar

struct WWProgressBar: View {
    var value: Double        // 0.0 – 1.0
    var height: CGFloat = 4
    var color: Color = .wwBlue
    var trackColor: Color = .wwDivider

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, value)), height: height)
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Status Badge

struct WWStatusBadge: View {
    enum Status { case notStarted, inProgress, completed }
    let status: Status
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            if !compact {
                Text(label)
                    .wwLabel(color: color)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .notStarted: return .wwTextMuted
        case .inProgress: return .wwBlue
        case .completed:  return .wwSuccess
        }
    }

    private var label: String {
        switch status {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        }
    }
}

// MARK: - Empty State

struct WWEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: WWSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.wwTextMuted)
            VStack(spacing: WWSpacing.s) {
                Text(title)
                    .wwSectionTitle()
                Text(message)
                    .wwBody(color: .wwTextSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                WWPrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 240)
            }
        }
        .padding(WWSpacing.xl)
    }
}

// MARK: - Divider

struct WWDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.wwDivider)
            .frame(height: 1)
    }
}

// MARK: - Section Header

struct WWSectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .wwLabel()
                .textCase(.uppercase)
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    Text(action)
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwBlue)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WWProgressBar(value: 0.6)
            .padding()
        WWCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Module 1").wwSectionTitle()
                Text("Electrical Fundamentals").wwBody(color: .wwTextSecondary)
                WWProgressBar(value: 0.4)
            }
        }
        .padding()
        HStack {
            WWStatusBadge(status: .notStarted)
            WWStatusBadge(status: .inProgress)
            WWStatusBadge(status: .completed)
        }
    }
}
