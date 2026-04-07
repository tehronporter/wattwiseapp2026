import SwiftUI

// TEHSO Design System — Spacing (8pt grid)

enum WWSpacing {
    static let xs: CGFloat   = 4
    static let s: CGFloat    = 8
    static let m: CGFloat    = 16
    static let l: CGFloat    = 24
    static let xl: CGFloat   = 32
    static let xxl: CGFloat  = 40
    static let xxxl: CGFloat = 48

    // Corner radii
    enum Radius {
        static let s: CGFloat  = 8
        static let m: CGFloat  = 12
        static let l: CGFloat  = 16
        static let pill: CGFloat = 100
    }

    // Minimum tap target
    static let minTapTarget: CGFloat = 44
}

// Screen horizontal padding
struct WWScreenPadding: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.horizontal, WWSpacing.m)
    }
}

extension View {
    func wwScreenPadding() -> some View {
        modifier(WWScreenPadding())
    }
}
