import SwiftUI

// MARK: - Design System
// Single source of truth for all design tokens used across the app.
// Ensures visual consistency and maintainability.

enum DS {

    // MARK: - Spacing Scale
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Typography
    enum Typography {
        static let caption2: Font = .system(size: 9)
        static let caption: Font = .system(size: 10)
        static let footnote: Font = .system(size: 11)
        static let subheadline: Font = .system(size: 12)
        static let body: Font = .system(size: 13)
        static let headline: Font = .system(size: 14, weight: .semibold)
        static let title3: Font = .system(size: 16, weight: .semibold)
        static let title2: Font = .system(size: 18, weight: .bold)

        static let monoCaption: Font = .system(size: 10, design: .monospaced)
        static let monoBody: Font = .system(size: 13, design: .monospaced)
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let pill: CGFloat = 100
    }

    // MARK: - Icon Sizes
    enum IconSize {
        static let inline: CGFloat = 12
        static let sm: CGFloat = 14
        static let md: CGFloat = 16
        static let action: CGFloat = 20
        static let primary: CGFloat = 24
    }

    // MARK: - Colors (Semantic)
    enum Colors {
        // Backgrounds
        static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
        static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)
        static let surfaceElevated = Color(nsColor: .underPageBackgroundColor)
        static let surfaceGrouped = Color(nsColor: .controlBackgroundColor).opacity(0.5)

        // Text
        static let textPrimary = Color(nsColor: .labelColor)
        static let textSecondary = Color(nsColor: .secondaryLabelColor)
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)
        static let textQuaternary = Color(nsColor: .quaternaryLabelColor)

        // Semantic
        static let accent = Color.accentColor
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        // Interactive
        static let controlFill = Color(nsColor: .controlColor)
        static let controlBorder = Color(nsColor: .separatorColor)
        static let hoverFill = Color(nsColor: .controlAccentColor).opacity(0.08)

        // Recording states
        static let recording = Color.red
        static let paused = Color.orange
        static let processing = Color.blue

        // AI
        static let aiAccent = Color.purple
        static let aiSurface = Color.purple.opacity(0.06)
        static let aiBorder = Color.purple.opacity(0.2)
    }

    // MARK: - Shadows
    enum Shadow {
        static let sm = ShadowStyle(color: .black.opacity(0.06), radius: 2, y: 1)
        static let md = ShadowStyle(color: .black.opacity(0.08), radius: 4, y: 2)
        static let lg = ShadowStyle(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
    }
}

// MARK: - Shadow Style Helper
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers

struct DSCardModifier: ViewModifier {
    var padding: CGFloat = DS.Spacing.md
    var radius: CGFloat = DS.Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DS.Colors.surfaceSecondary)
            .cornerRadius(radius)
    }
}

struct DSToolbarButtonModifier: ViewModifier {
    var isActive: Bool = false
    var size: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(
                isActive
                    ? DS.Colors.accent.opacity(0.12)
                    : Color.clear
            )
            .cornerRadius(DS.Radius.md)
            .contentShape(Rectangle())
    }
}

struct DSSegmentedTab: ViewModifier {
    var isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(DS.Typography.subheadline)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected
                    ? DS.Colors.surfacePrimary
                    : Color.clear
            )
            .cornerRadius(DS.Radius.sm)
            .shadow(
                color: isSelected ? .black.opacity(0.06) : .clear,
                radius: 1, y: 1
            )
    }
}

// MARK: - View Extensions

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.md, radius: CGFloat = DS.Radius.lg) -> some View {
        modifier(DSCardModifier(padding: padding, radius: radius))
    }

    func dsToolbarButton(isActive: Bool = false, size: CGFloat = 28) -> some View {
        modifier(DSToolbarButtonModifier(isActive: isActive, size: size))
    }

    func dsSegmentedTab(isSelected: Bool) -> some View {
        modifier(DSSegmentedTab(isSelected: isSelected))
    }

    func dsShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }

    func dsHoverEffect() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
