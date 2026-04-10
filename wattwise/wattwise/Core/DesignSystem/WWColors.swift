import SwiftUI

// TEHSO Design System — Color Palette
// Primary accent: #2E53FF | Background adapts to light/dark mode

extension Color {
    // MARK: - Brand (fixed — never adapts)
    static let wwBlue    = Color(hex: "#2E53FF")
    static let wwBlueDim = Color(hex: "#2E53FF").opacity(0.12)

    // MARK: - Backgrounds (adaptive — light/dark aware)
    static let wwBackground = Color(UIColor.systemBackground)
    static let wwSurface    = Color(UIColor.secondarySystemBackground)
    static let wwDivider    = Color(UIColor.separator).opacity(0.6)

    // MARK: - Text (adaptive)
    static let wwTextPrimary   = Color(UIColor.label)
    static let wwTextSecondary = Color(UIColor.secondaryLabel)
    static let wwTextMuted     = Color(UIColor.tertiaryLabel)

    // MARK: - Semantic (fixed)
    static let wwSuccess = Color(hex: "#1DB954")
    static let wwError   = Color(hex: "#E5534B")
    static let wwWarning = Color(hex: "#F0A500")

    // MARK: - Topic Accent (supplementary, for Learn path nodes)
    static let wwTopicGreen  = Color(hex: "#2E8B57")   // grounding / bonding
    static let wwTopicAmber  = Color(hex: "#B8860B")   // wiring methods / conduit
    static let wwTopicPurple = Color(hex: "#7B3FA0")   // NEC / GFCI / code

    // MARK: - Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
