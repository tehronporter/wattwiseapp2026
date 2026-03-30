import SwiftUI

// TEHSO Design System — Typography
// Uses Inter font family. Add Inter .ttf files to the project and register in Info.plist.
// Falls back to SF Pro if Inter is unavailable.

enum WWFont {
    // MARK: - Sizes
    static let display: CGFloat   = 34
    static let h1: CGFloat        = 28
    static let h2: CGFloat        = 22
    static let h3: CGFloat        = 18
    static let bodyLg: CGFloat    = 17
    static let body: CGFloat      = 15
    static let caption: CGFloat   = 13
    static let label: CGFloat     = 11

    // MARK: - Named font builders
    static func display(_ weight: Font.Weight = .black) -> Font {
        inter(size: display, weight: weight)
    }
    static func heading(_ weight: Font.Weight = .bold) -> Font {
        inter(size: h1, weight: weight)
    }
    static func subheading(_ weight: Font.Weight = .semibold) -> Font {
        inter(size: h2, weight: weight)
    }
    static func sectionTitle(_ weight: Font.Weight = .semibold) -> Font {
        inter(size: h3, weight: weight)
    }
    static func bodyLarge(_ weight: Font.Weight = .regular) -> Font {
        inter(size: bodyLg, weight: weight)
    }
    static func body(_ weight: Font.Weight = .regular) -> Font {
        inter(size: body, weight: weight)
    }
    static func caption(_ weight: Font.Weight = .regular) -> Font {
        inter(size: caption, weight: weight)
    }
    static func label(_ weight: Font.Weight = .medium) -> Font {
        inter(size: label, weight: weight)
    }

    // MARK: - Private
    private static func inter(size: CGFloat, weight: Font.Weight) -> Font {
        let name: String
        switch weight {
        case .black:              name = "Inter-Black"
        case .heavy:              name = "Inter-ExtraBold"
        case .bold:               name = "Inter-Bold"
        case .semibold:           name = "Inter-SemiBold"
        case .medium:             name = "Inter-Medium"
        default:                  name = "Inter-Regular"
        }
        return Font.custom(name, size: size).weight(weight)
    }
}

// Convenience view modifier
struct WWTextStyle: ViewModifier {
    let font: Font
    let color: Color
    let tracking: CGFloat

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
            .tracking(tracking)
    }
}

extension View {
    func wwDisplay() -> some View {
        modifier(WWTextStyle(font: WWFont.display(), color: .wwTextPrimary, tracking: -0.5))
    }
    func wwHeading() -> some View {
        modifier(WWTextStyle(font: WWFont.heading(), color: .wwTextPrimary, tracking: -0.3))
    }
    func wwSubheading() -> some View {
        modifier(WWTextStyle(font: WWFont.subheading(), color: .wwTextPrimary, tracking: -0.2))
    }
    func wwSectionTitle() -> some View {
        modifier(WWTextStyle(font: WWFont.sectionTitle(), color: .wwTextPrimary, tracking: 0))
    }
    func wwBody(color: Color = .wwTextPrimary) -> some View {
        modifier(WWTextStyle(font: WWFont.body(), color: color, tracking: 0))
    }
    func wwBodyLarge(color: Color = .wwTextPrimary) -> some View {
        modifier(WWTextStyle(font: WWFont.bodyLarge(), color: color, tracking: 0))
    }
    func wwCaption(color: Color = .wwTextSecondary) -> some View {
        modifier(WWTextStyle(font: WWFont.caption(), color: color, tracking: 0.2))
    }
    func wwLabel(color: Color = .wwTextMuted) -> some View {
        modifier(WWTextStyle(font: WWFont.label(), color: color, tracking: 0.5))
    }
}
