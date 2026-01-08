// MaDesignSystem.swift
// Design system for Ma - The space to breathe
//
// Ma (間) represents negative space, pause, and the gap between elements.
// This design system embodies calmness, breathing room, and gentle aesthetics.

import SwiftUI

// MARK: - Ma Color Palette

/// The Ma color palette - soft, calming colors inspired by nature
/// Works beautifully in both light and dark modes
struct MaColors {

    // MARK: - Primary Palette (Soft Sky/Water tones)

    /// Primary brand color - a soft, calming blue
    static let primary = Color("MaPrimary", bundle: nil)
    static let primaryLight = Color(light: .init(hex: "#7EB8DA"), dark: .init(hex: "#5BA3C9"))
    static let primarySoft = Color(light: .init(hex: "#B8D4E8"), dark: .init(hex: "#2E5A7A"))

    // MARK: - Secondary Palette (Warm Earth tones)

    /// Secondary accent - warm, grounding tones
    static let secondary = Color(light: .init(hex: "#D4A574"), dark: .init(hex: "#C49664"))
    static let secondarySoft = Color(light: .init(hex: "#EBD8C3"), dark: .init(hex: "#4A3728"))

    // MARK: - Semantic Colors

    /// Success/Complete - Soft sage green (calming, not harsh)
    static let complete = Color(light: .init(hex: "#8FBC8F"), dark: .init(hex: "#6B9B6B"))
    static let completeSoft = Color(light: .init(hex: "#D4E8D4"), dark: .init(hex: "#2D4A2D"))

    /// Warning/Postpone - Soft amber/honey
    static let postpone = Color(light: .init(hex: "#E8B86D"), dark: .init(hex: "#D4A55A"))
    static let postponeSoft = Color(light: .init(hex: "#F5E6C8"), dark: .init(hex: "#4A3D28"))

    /// Error/Overdue - Soft coral (not harsh red)
    static let overdue = Color(light: .init(hex: "#E88B8B"), dark: .init(hex: "#D47A7A"))
    static let overdueSoft = Color(light: .init(hex: "#F5D4D4"), dark: .init(hex: "#4A2D2D"))

    /// Skip/Neutral - Soft gray with warmth
    static let skip = Color(light: .init(hex: "#A8A8A0"), dark: .init(hex: "#8A8A82"))
    static let skipSoft = Color(light: .init(hex: "#E8E8E4"), dark: .init(hex: "#3A3A38"))

    // MARK: - Gamification Colors

    /// Streak flame - Warm gradient base
    static let streak = Color(light: .init(hex: "#F5A855"), dark: .init(hex: "#E89845"))
    static let streakHot = Color(light: .init(hex: "#E87D55"), dark: .init(hex: "#D46D45"))

    /// XP/Reward - Soft purple/lavender
    static let xp = Color(light: .init(hex: "#A68BC8"), dark: .init(hex: "#9678B8"))
    static let xpSoft = Color(light: .init(hex: "#E0D4EB"), dark: .init(hex: "#3D2D4A"))

    /// Trophy/Achievement - Soft gold
    static let trophy = Color(light: .init(hex: "#D4B86A"), dark: .init(hex: "#C4A85A"))

    // MARK: - Background Colors

    /// Main background - subtle warmth
    static let background = Color(light: .init(hex: "#FAF8F5"), dark: .init(hex: "#1A1918"))

    /// Secondary background - for cards and sections
    static let backgroundSecondary = Color(light: .init(hex: "#FFFFFF"), dark: .init(hex: "#252423"))

    /// Tertiary background - subtle grouping
    static let backgroundTertiary = Color(light: .init(hex: "#F5F3F0"), dark: .init(hex: "#2D2C2A"))

    // MARK: - Text Colors

    /// Primary text
    static let textPrimary = Color(light: .init(hex: "#2D2A26"), dark: .init(hex: "#F5F3F0"))

    /// Secondary text
    static let textSecondary = Color(light: .init(hex: "#6B6560"), dark: .init(hex: "#A8A5A0"))

    /// Tertiary/Muted text
    static let textTertiary = Color(light: .init(hex: "#A8A5A0"), dark: .init(hex: "#6B6560"))

    // MARK: - Border & Divider Colors

    static let divider = Color(light: .init(hex: "#E8E5E0"), dark: .init(hex: "#3A3835"))
    static let border = Color(light: .init(hex: "#D4D0C8"), dark: .init(hex: "#4A4540"))

    // MARK: - Status Colors for Timeline

    static func statusColor(for status: ItemStatus, isOverdue: Bool = false) -> Color {
        if isOverdue { return overdue }
        switch status {
        case .pending: return skip
        case .active: return primaryLight
        case .upcoming: return textTertiary
        case .completed: return complete
        case .skipped: return skip
        case .postponed: return postpone
        }
    }

    static func statusSoftColor(for status: ItemStatus, isOverdue: Bool = false) -> Color {
        if isOverdue { return overdueSoft }
        switch status {
        case .pending: return skipSoft
        case .active: return primarySoft
        case .upcoming: return backgroundTertiary
        case .completed: return completeSoft
        case .skipped: return skipSoft
        case .postponed: return postponeSoft
        }
    }
}

// MARK: - Color Extension for Hex and Adaptive Colors

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Creates an adaptive color for light and dark mode
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Ma Typography

struct MaTypography {

    // MARK: - Display

    /// Large display text for headers
    static let displayLarge = Font.system(size: 34, weight: .light, design: .rounded)
    static let displayMedium = Font.system(size: 28, weight: .light, design: .rounded)

    // MARK: - Titles

    static let titleLarge = Font.system(size: 22, weight: .medium, design: .rounded)
    static let titleMedium = Font.system(size: 18, weight: .medium, design: .rounded)
    static let titleSmall = Font.system(size: 16, weight: .medium, design: .rounded)

    // MARK: - Body

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Labels

    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - Captions

    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)

    // MARK: - Numbers (for stats and gamification)

    static let statLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let statMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let statSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
}

// MARK: - Ma Spacing

struct MaSpacing {
    /// 4pt - Hairline spacing
    static let xxxs: CGFloat = 4
    /// 6pt - Minimal spacing
    static let xxs: CGFloat = 6
    /// 8pt - Tight spacing
    static let xs: CGFloat = 8
    /// 12pt - Compact spacing
    static let sm: CGFloat = 12
    /// 16pt - Default spacing (breathing room)
    static let md: CGFloat = 16
    /// 20pt - Comfortable spacing
    static let lg: CGFloat = 20
    /// 24pt - Generous spacing
    static let xl: CGFloat = 24
    /// 32pt - Section spacing
    static let xxl: CGFloat = 32
    /// 40pt - Major section breaks
    static let xxxl: CGFloat = 40
    /// 48pt - Page-level spacing
    static let huge: CGFloat = 48
}

// MARK: - Ma Corner Radius

struct MaRadius {
    /// 4pt - Subtle rounding
    static let xs: CGFloat = 4
    /// 8pt - Light rounding
    static let sm: CGFloat = 8
    /// 12pt - Default card rounding
    static let md: CGFloat = 12
    /// 16pt - Prominent rounding
    static let lg: CGFloat = 16
    /// 20pt - Large element rounding
    static let xl: CGFloat = 20
    /// 24pt - Very rounded
    static let xxl: CGFloat = 24
    /// Full pill shape
    static let full: CGFloat = 9999
}

// MARK: - Ma Shadows

struct MaShadow {

    /// Soft elevation shadow for cards
    static func soft(colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: MaRadius.md)
            .fill(colorScheme == .dark ? Color.clear : Color.white)
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.06),
                radius: 8,
                x: 0,
                y: 2
            )
    }

    /// Subtle shadow for interactive elements
    static func subtle(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.2)
            : Color.black.opacity(0.04)
    }

    /// No shadow in dark mode, soft in light
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2
}

// MARK: - Ma Gradients

struct MaGradients {

    /// Soft sunrise gradient for backgrounds
    static let sunrise = LinearGradient(
        colors: [
            Color(light: .init(hex: "#FDF6E3"), dark: .init(hex: "#1F1D1A")),
            Color(light: .init(hex: "#F5EBE0"), dark: .init(hex: "#1A1918"))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Soft sky gradient
    static let sky = LinearGradient(
        colors: [
            Color(light: .init(hex: "#E8F4F8"), dark: .init(hex: "#1A2228")),
            Color(light: .init(hex: "#F5F8FA"), dark: .init(hex: "#1A1918"))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Streak flame gradient (for gamification warmth)
    static let flame = LinearGradient(
        colors: [
            MaColors.streakHot,
            MaColors.streak
        ],
        startPoint: .bottom,
        endPoint: .top
    )

    /// XP reward shimmer
    static let xpShimmer = LinearGradient(
        colors: [
            MaColors.xp,
            MaColors.xp.opacity(0.7),
            MaColors.xp
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Complete success gradient
    static let success = LinearGradient(
        colors: [
            MaColors.complete,
            MaColors.complete.opacity(0.8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Flowing Timeline Gradients

    /// Timeline path gradient - subtle glow effect
    static func timelinePath(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                MaColors.border.opacity(0.1),
                MaColors.primaryLight.opacity(0.3),
                MaColors.primaryLight.opacity(0.4),
                MaColors.primaryLight.opacity(0.3),
                MaColors.border.opacity(0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Timeline glow gradient for ambient effect
    static func timelineGlow(intensity: CGFloat) -> LinearGradient {
        LinearGradient(
            colors: [
                MaColors.primarySoft.opacity(0.0),
                MaColors.primarySoft.opacity(0.1 + intensity * 0.05),
                MaColors.primarySoft.opacity(0.15 + intensity * 0.05),
                MaColors.primarySoft.opacity(0.1 + intensity * 0.05),
                MaColors.primarySoft.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Bubble border gradient
    static func bubbleBorder(color: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.4),
                color.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Header fade gradient
    static func headerFade(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                MaColors.background,
                MaColors.background.opacity(0.95),
                MaColors.background.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Now indicator radial gradient
    static let nowIndicator = RadialGradient(
        colors: [
            MaColors.primaryLight.opacity(0.3),
            MaColors.primarySoft.opacity(0.1),
            Color.clear
        ],
        center: .center,
        startRadius: 5,
        endRadius: 25
    )
}

// MARK: - Ma Animation Timing

struct MaAnimation {
    /// Quick micro-interactions (100ms)
    static let quick = Animation.easeOut(duration: 0.1)

    /// Standard transitions (200ms)
    static let standard = Animation.easeInOut(duration: 0.2)

    /// Smooth, calming transitions (300ms)
    static let smooth = Animation.easeInOut(duration: 0.3)

    /// Gentle, breathing animations (400ms)
    static let gentle = Animation.easeInOut(duration: 0.4)

    /// Slow, contemplative animations (600ms)
    static let contemplative = Animation.easeInOut(duration: 0.6)

    /// Spring animation for playful feedback
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Soft bounce for rewards
    static let reward = Animation.spring(response: 0.4, dampingFraction: 0.6)

    // MARK: - Flowing Timeline Animations

    /// Breathing animation for zen elements (4 seconds)
    static let breathe = Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)

    /// Gentle floating motion (6 seconds)
    static let float = Animation.easeInOut(duration: 6).repeatForever(autoreverses: true)

    /// Particle flow animation
    static let particleFlow = Animation.linear(duration: 20).repeatForever(autoreverses: false)

    /// Bubble entrance spring
    static let bubbleEntrance = Animation.spring(response: 0.5, dampingFraction: 0.8)

    /// Bubble exit animation
    static let bubbleExit = Animation.easeIn(duration: 0.3)

    /// Celebration burst
    static let celebration = Animation.spring(response: 0.3, dampingFraction: 0.6)

    /// Shimmer effect
    static let shimmer = Animation.linear(duration: 3)

    /// Pulse for attention (2 seconds)
    static let pulse = Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)

    /// Colon blink for clock display
    static let clockBlink = Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
}

// MARK: - Ma Card Style

struct MaCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var padding: CGFloat = MaSpacing.md
    var cornerRadius: CGFloat = MaRadius.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(MaColors.backgroundSecondary)
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.clear
                            : Color.black.opacity(0.05),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
    }
}

extension View {
    func maCard(padding: CGFloat = MaSpacing.md, cornerRadius: CGFloat = MaRadius.md) -> some View {
        modifier(MaCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - Ma Button Styles

struct MaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    var color: Color = MaColors.complete

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MaTypography.labelLarge)
            .foregroundStyle(.white)
            .padding(.horizontal, MaSpacing.lg)
            .padding(.vertical, MaSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: MaRadius.md)
                    .fill(isEnabled ? color : MaColors.skip)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(MaAnimation.quick, value: configuration.isPressed)
    }
}

struct MaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MaTypography.labelLarge)
            .foregroundStyle(MaColors.textPrimary)
            .padding(.horizontal, MaSpacing.lg)
            .padding(.vertical, MaSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: MaRadius.md)
                    .fill(MaColors.backgroundTertiary)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(MaAnimation.quick, value: configuration.isPressed)
    }
}

struct MaGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MaTypography.labelMedium)
            .foregroundStyle(MaColors.textSecondary)
            .padding(.horizontal, MaSpacing.sm)
            .padding(.vertical, MaSpacing.xs)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(MaAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Ma Badge Style (for streaks, XP, etc.)

struct MaBadge: View {
    let icon: String
    let value: String
    let color: Color
    var softBackground: Color? = nil
    var showFlame: Bool = false

    var body: some View {
        HStack(spacing: MaSpacing.xxxs) {
            if showFlame {
                Image(systemName: icon)
                    .symbolRenderingMode(.multicolor)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            Text(value)
                .foregroundStyle(color)
        }
        .font(MaTypography.labelSmall)
        .padding(.horizontal, MaSpacing.xs)
        .padding(.vertical, MaSpacing.xxxs)
        .background(
            Capsule()
                .fill(softBackground ?? color.opacity(0.15))
        )
    }
}

// MARK: - Ma Status Indicator

struct MaStatusDot: View {
    let status: ItemStatus
    let isOverdue: Bool
    var size: CGFloat = 10
    var animated: Bool = false

    @State private var isGlowing = false

    var body: some View {
        ZStack {
            // Glow effect for active items
            if animated && (status == .active || isOverdue) {
                Circle()
                    .fill(MaColors.statusColor(for: status, isOverdue: isOverdue))
                    .frame(width: size + 4, height: size + 4)
                    .opacity(isGlowing ? 0.4 : 0.1)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isGlowing
                    )
            }

            Circle()
                .fill(MaColors.statusColor(for: status, isOverdue: isOverdue))
                .frame(width: size, height: size)
        }
        .onAppear {
            if animated {
                isGlowing = true
            }
        }
    }
}

// MARK: - Ma Streak Display

struct MaStreakBadge: View {
    let streak: Int
    var isCompact: Bool = false

    var body: some View {
        if streak > 0 {
            HStack(spacing: MaSpacing.xxxs) {
                // Flame icon with gradient fill
                Image(systemName: streakIcon)
                    .foregroundStyle(MaGradients.flame)

                if !isCompact {
                    Text("\(streak)")
                        .font(isCompact ? MaTypography.captionSmall : MaTypography.labelSmall)
                        .foregroundStyle(MaColors.streak)
                }
            }
            .padding(.horizontal, isCompact ? MaSpacing.xxs : MaSpacing.xs)
            .padding(.vertical, MaSpacing.xxxs)
            .background(
                Capsule()
                    .fill(MaColors.secondarySoft.opacity(0.5))
            )
        }
    }

    private var streakIcon: String {
        if streak >= 30 {
            return "flame.fill"
        } else if streak >= 7 {
            return "flame"
        } else {
            return "flame"
        }
    }
}

// MARK: - Ma XP Badge

struct MaXPBadge: View {
    let xp: Int
    var showPlus: Bool = true
    var isCompact: Bool = false

    var body: some View {
        if xp > 0 {
            HStack(spacing: MaSpacing.xxxs) {
                Image(systemName: "sparkles")
                    .foregroundStyle(MaColors.xp)

                Text(showPlus ? "+\(xp)" : "\(xp)")
                    .font(isCompact ? MaTypography.captionSmall : MaTypography.labelSmall)
                    .foregroundStyle(MaColors.xp)
            }
            .padding(.horizontal, isCompact ? MaSpacing.xxs : MaSpacing.xs)
            .padding(.vertical, MaSpacing.xxxs)
            .background(
                Capsule()
                    .fill(MaColors.xpSoft.opacity(0.5))
            )
        }
    }
}

// MARK: - Preview Support

#Preview("Ma Colors") {
    ScrollView {
        VStack(spacing: 20) {
            Group {
                Text("Primary Colors")
                    .font(MaTypography.titleMedium)
                HStack {
                    colorSwatch(MaColors.primaryLight, "Primary Light")
                    colorSwatch(MaColors.primarySoft, "Primary Soft")
                }
            }

            Group {
                Text("Semantic Colors")
                    .font(MaTypography.titleMedium)
                HStack {
                    colorSwatch(MaColors.complete, "Complete")
                    colorSwatch(MaColors.postpone, "Postpone")
                    colorSwatch(MaColors.overdue, "Overdue")
                }
            }

            Group {
                Text("Gamification")
                    .font(MaTypography.titleMedium)
                HStack {
                    colorSwatch(MaColors.streak, "Streak")
                    colorSwatch(MaColors.xp, "XP")
                    colorSwatch(MaColors.trophy, "Trophy")
                }
            }

            Group {
                Text("Badges")
                    .font(MaTypography.titleMedium)
                HStack(spacing: 12) {
                    MaStreakBadge(streak: 7)
                    MaStreakBadge(streak: 30)
                    MaXPBadge(xp: 25)
                }
            }
        }
        .padding()
    }
    .background(MaColors.background)
}

@ViewBuilder
private func colorSwatch(_ color: Color, _ name: String) -> some View {
    VStack {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 60, height: 60)
        Text(name)
            .font(.caption2)
    }
}
