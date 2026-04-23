import SwiftUI

// MARK: - Celebration Overlay

/// Full-screen celebration shown after completing a lesson or quiz.
/// Present as an overlay on the parent view, dismissed only via the "Continue" button.
struct WWCelebrationOverlay: View {
    let headline: String
    let xpEarned: Int
    let streakDays: Int
    let accuracyPercent: Int?          // nil for lesson completions
    let onContinue: () -> Void
    var secondaryActionTitle: String? = nil
    var onSecondaryAction: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Backdrop
            Color.wwBackground
                .ignoresSafeArea()
                .opacity(0.97)

            // Confetti layer
            WWAnimatedConfetti()
                .ignoresSafeArea()

            // Content card
            VStack(spacing: WWSpacing.l) {
                Spacer()

                // Checkmark circle
                ZStack {
                    Circle()
                        .fill(Color.wwBlue.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(Color.wwBlue)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(appeared ? 1.0 : 0.4)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.05), value: appeared)

                // Headline
                Text(headline)
                    .font(WWFont.heading(.bold))
                    .foregroundColor(.wwTextPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.35).delay(0.2), value: appeared)

                // Stats row
                HStack(spacing: WWSpacing.m) {
                    CelebrationStat(
                        icon: "bolt.fill",
                        value: "+\(xpEarned)",
                        label: "XP",
                        color: .wwSuccess
                    )

                    CelebrationStat(
                        icon: "flame.fill",
                        value: "\(streakDays)",
                        label: streakDays == 1 ? "Day Streak" : "Day Streak",
                        color: .wwBlue
                    )

                    if let pct = accuracyPercent {
                        CelebrationStat(
                            icon: "target",
                            value: "\(pct)%",
                            label: "Accuracy",
                            color: pct >= 70 ? .wwSuccess : .wwWarning
                        )
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.easeOut(duration: 0.35).delay(0.3), value: appeared)

                Spacer()

                // Continue button
                VStack(spacing: WWSpacing.s) {
                    WWPrimaryButton(title: "Continue", action: onContinue)

                    if let secondaryTitle = secondaryActionTitle, let onSecondary = onSecondaryAction {
                        WWGhostButton(title: secondaryTitle, color: .wwBlue, action: onSecondary)
                    }
                }
                .wwScreenPadding()
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.35).delay(0.45), value: appeared)
            }
        }
        .onAppear {
            appeared = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

// MARK: - Celebration Stat Pill

private struct CelebrationStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(value)
                    .font(WWFont.subheading(.bold))
                    .foregroundColor(.wwTextPrimary)
            }
            Text(label)
                .font(WWFont.label(.medium))
                .foregroundColor(.wwTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WWSpacing.m)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    WWCelebrationOverlay(
        headline: "Lesson Complete!",
        xpEarned: 50,
        streakDays: 4,
        accuracyPercent: nil,
        onContinue: {}
    )
}
