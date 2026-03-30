import SwiftUI

// MARK: - Primary Button

struct WWPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(WWFont.body(.semibold))
                        .foregroundColor(.white)
                        .tracking(0.1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: WWSpacing.minTapTarget + 4)
            .background(isDisabled ? Color.wwBlue.opacity(0.4) : Color.wwBlue)
            .clipShape(Capsule())
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button (Outline)

struct WWSecondaryButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WWFont.body(.semibold))
                .foregroundColor(isDisabled ? .wwTextMuted : .wwBlue)
                .tracking(0.1)
                .frame(maxWidth: .infinity)
                .frame(height: WWSpacing.minTapTarget + 4)
                .overlay(
                    Capsule()
                        .strokeBorder(isDisabled ? Color.wwDivider : Color.wwBlue, lineWidth: 1.5)
                )
        }
        .disabled(isDisabled)
    }
}

// MARK: - Ghost Button (text only)

struct WWGhostButton: View {
    let title: String
    var color: Color = .wwTextSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WWFont.body(.medium))
                .foregroundColor(color)
                .frame(height: WWSpacing.minTapTarget)
        }
    }
}

// MARK: - Icon Button

struct WWIconButton: View {
    let systemName: String
    var color: Color = .wwTextPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(color)
                .frame(width: WWSpacing.minTapTarget, height: WWSpacing.minTapTarget)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        WWPrimaryButton(title: "Start Studying") {}
        WWPrimaryButton(title: "Loading…", isLoading: true) {}
        WWSecondaryButton(title: "Sign In") {}
        WWGhostButton(title: "Skip for now") {}
    }
    .padding()
}
