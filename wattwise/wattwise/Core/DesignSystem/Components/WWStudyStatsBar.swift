import SwiftUI

// MARK: - Study Stats Bar

/// Persistent top bar showing streak, level progress, and total XP.
/// Attach via `.safeAreaInset(edge: .top)` on RootTabView.
struct WWStudyStatsBar: View {
    let streakDays: Int
    let totalXP: Int
    let levelProgress: Double
    let levelLabel: String
    let currentLevel: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: WWSpacing.m) {
                // Streak
                Label("\(streakDays)", systemImage: "flame.fill")
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)

                // Level progress (center)
                VStack(spacing: 3) {
                    WWProgressBar(value: levelProgress, height: 4, color: .wwBlue)
                    Text("\(levelLabel) · Lv \(currentLevel)")
                        .font(WWFont.label(.medium))
                        .foregroundColor(.wwTextMuted)
                }

                // XP
                Label(formattedXP, systemImage: "bolt.fill")
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
            }
            .padding(.horizontal, WWSpacing.m)
            .padding(.vertical, WWSpacing.s)

            Rectangle()
                .fill(Color.wwDivider)
                .frame(height: 1)
        }
        .background(Color.wwBackground)
    }

    private var formattedXP: String {
        totalXP >= 1000
            ? String(format: "%.1fk", Double(totalXP) / 1000.0)
            : "\(totalXP)"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        WWStudyStatsBar(
            streakDays: 7,
            totalXP: 1340,
            levelProgress: 0.68,
            levelLabel: "Journeyman",
            currentLevel: 2
        )
        Spacer()
    }
}
