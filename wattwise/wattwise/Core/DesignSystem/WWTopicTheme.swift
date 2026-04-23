import SwiftUI

// MARK: - Topic Theme

/// Maps a module's topic tags to a visual identity (color + SF Symbol icon)
/// used by the Learn path node view.
struct WWTopicTheme {
    let color: Color
    let icon: String    // SF Symbol name
    let label: String   // Human-readable section name shown on the learn path

    static func theme(for tags: [String]) -> WWTopicTheme {
        let lower = tags.map { $0.lowercased() }

        if lower.contains(where: { $0.contains("grounding") || $0.contains("bonding") || $0.contains("ground") }) {
            return WWTopicTheme(color: .wwTopicGreen, icon: "bolt.shield.fill", label: "Grounding & Bonding")
        }
        if lower.contains(where: { $0.contains("wiring") || $0.contains("conduit") || $0.contains("cable") || $0.contains("raceway") }) {
            return WWTopicTheme(color: .wwTopicAmber, icon: "cable.connector", label: "Wiring Methods")
        }
        if lower.contains(where: { $0.contains("nec") || $0.contains("gfci") || $0.contains("afci") || $0.contains("code") || $0.contains("article") }) {
            return WWTopicTheme(color: .wwTopicPurple, icon: "book.pages.fill", label: "NEC Code & Articles")
        }
        if lower.contains(where: { $0.contains("calculation") || $0.contains("ampacity") || $0.contains("load") || $0.contains("voltage") || $0.contains("math") }) {
            return WWTopicTheme(color: .wwWarning, icon: "function", label: "Calculations & Math")
        }
        if lower.contains(where: { $0.contains("safety") || $0.contains("protection") || $0.contains("lockout") }) {
            return WWTopicTheme(color: .wwSuccess, icon: "checkmark.shield.fill", label: "Safety & Protection")
        }
        // Default — fundamentals / general
        return WWTopicTheme(color: .wwBlue, icon: "bolt.circle.fill", label: "Electrical Fundamentals")
    }
}
