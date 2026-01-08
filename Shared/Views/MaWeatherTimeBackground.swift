// MaWeatherTimeBackground.swift
// A dynamic, time and weather-aware background for the Ma timeline
//
// Ma (間) - The space to breathe
//
// This background creates an ambient atmosphere that reflects:
// - Time of day (dawn, morning, afternoon, evening, night)
// - Weather conditions (clear, cloudy, rainy, snowy)
// - Smooth transitions as the user scrolls through time

import SwiftUI

// MARK: - Time Period

enum TimePeriod: CaseIterable {
    case night       // 00:00 - 05:00
    case dawn        // 05:00 - 07:00
    case morning     // 07:00 - 12:00
    case afternoon   // 12:00 - 17:00
    case evening     // 17:00 - 20:00
    case dusk        // 20:00 - 22:00
    case lateNight   // 22:00 - 00:00

    static func from(hour: Int) -> TimePeriod {
        switch hour {
        case 0..<5: return .night
        case 5..<7: return .dawn
        case 7..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<22: return .dusk
        default: return .lateNight
        }
    }

    /// Returns progress within the period (0.0 to 1.0) and the next period
    static func progressAndNext(hour: Int, minute: Int) -> (progress: Double, current: TimePeriod, next: TimePeriod) {
        let current = from(hour: hour)
        let allPeriods = TimePeriod.allCases
        let currentIndex = allPeriods.firstIndex(of: current) ?? 0
        let nextIndex = (currentIndex + 1) % allPeriods.count
        let next = allPeriods[nextIndex]

        // Calculate progress within current period
        let hourRanges: [(start: Int, end: Int)] = [
            (0, 5),   // night
            (5, 7),   // dawn
            (7, 12),  // morning
            (12, 17), // afternoon
            (17, 20), // evening
            (20, 22), // dusk
            (22, 24)  // lateNight
        ]

        let range = hourRanges[currentIndex]
        let totalMinutes = (range.end - range.start) * 60
        let currentMinutes = (hour - range.start) * 60 + minute
        let progress = Double(currentMinutes) / Double(totalMinutes)

        return (progress, current, next)
    }
}

// MARK: - Weather Condition

enum WeatherCondition {
    case clear
    case partlyCloudy
    case cloudy
    case rainy
    case snowy
    case foggy

    var cloudDensity: Double {
        switch self {
        case .clear: return 0.0
        case .partlyCloudy: return 0.3
        case .cloudy, .rainy: return 0.7
        case .snowy: return 0.5
        case .foggy: return 0.4
        }
    }

    var hasPrecipitation: Bool {
        self == .rainy || self == .snowy
    }
}

// MARK: - Sky Colors

struct SkyPalette {
    let topColor: Color
    let bottomColor: Color
    let ambientColor: Color

    static func forPeriod(_ period: TimePeriod, colorScheme: ColorScheme) -> SkyPalette {
        if colorScheme == .dark {
            return darkModePalette(for: period)
        } else {
            return lightModePalette(for: period)
        }
    }

    private static func lightModePalette(for period: TimePeriod) -> SkyPalette {
        switch period {
        case .night, .lateNight:
            return SkyPalette(
                topColor: Color(hex: "#0D1B2A"),
                bottomColor: Color(hex: "#1B263B"),
                ambientColor: Color(hex: "#415A77").opacity(0.3)
            )
        case .dawn:
            return SkyPalette(
                topColor: Color(hex: "#2D3A4D"),
                bottomColor: Color(hex: "#E8A87C"),
                ambientColor: Color(hex: "#F5CBA7").opacity(0.4)
            )
        case .morning:
            return SkyPalette(
                topColor: Color(hex: "#87CEEB"),
                bottomColor: Color(hex: "#E0F4FF"),
                ambientColor: Color(hex: "#FFE4B5").opacity(0.2)
            )
        case .afternoon:
            return SkyPalette(
                topColor: Color(hex: "#5DADE2"),
                bottomColor: Color(hex: "#AED6F1"),
                ambientColor: Color(hex: "#FFFFFF").opacity(0.3)
            )
        case .evening:
            return SkyPalette(
                topColor: Color(hex: "#5B7DB1"),
                bottomColor: Color(hex: "#F4A460"),
                ambientColor: Color(hex: "#FFB347").opacity(0.4)
            )
        case .dusk:
            return SkyPalette(
                topColor: Color(hex: "#2E4057"),
                bottomColor: Color(hex: "#8B5A5A"),
                ambientColor: Color(hex: "#C77B7B").opacity(0.3)
            )
        }
    }

    private static func darkModePalette(for period: TimePeriod) -> SkyPalette {
        // In dark mode, all times are muted and darker
        switch period {
        case .night, .lateNight:
            return SkyPalette(
                topColor: Color(hex: "#0A0F14"),
                bottomColor: Color(hex: "#151C24"),
                ambientColor: Color(hex: "#1E2832").opacity(0.4)
            )
        case .dawn:
            return SkyPalette(
                topColor: Color(hex: "#141820"),
                bottomColor: Color(hex: "#2A2520"),
                ambientColor: Color(hex: "#3D3328").opacity(0.3)
            )
        case .morning:
            return SkyPalette(
                topColor: Color(hex: "#1A2530"),
                bottomColor: Color(hex: "#202830"),
                ambientColor: Color(hex: "#283040").opacity(0.3)
            )
        case .afternoon:
            return SkyPalette(
                topColor: Color(hex: "#1E2835"),
                bottomColor: Color(hex: "#232D38"),
                ambientColor: Color(hex: "#2D3845").opacity(0.3)
            )
        case .evening:
            return SkyPalette(
                topColor: Color(hex: "#181D25"),
                bottomColor: Color(hex: "#25201F"),
                ambientColor: Color(hex: "#352820").opacity(0.3)
            )
        case .dusk:
            return SkyPalette(
                topColor: Color(hex: "#12161C"),
                bottomColor: Color(hex: "#1E1A1A"),
                ambientColor: Color(hex: "#281818").opacity(0.3)
            )
        }
    }

    /// Interpolates between two palettes
    static func interpolate(from: SkyPalette, to: SkyPalette, progress: Double) -> SkyPalette {
        SkyPalette(
            topColor: interpolateColor(from: from.topColor, to: to.topColor, progress: progress),
            bottomColor: interpolateColor(from: from.bottomColor, to: to.bottomColor, progress: progress),
            ambientColor: interpolateColor(from: from.ambientColor, to: to.ambientColor, progress: progress)
        )
    }

    private static func interpolateColor(from: Color, to: Color, progress: Double) -> Color {
        // SwiftUI doesn't have built-in color interpolation, so we use opacity blending
        // For smoother results, we'd need to extract RGB components
        if progress < 0.5 {
            return from.opacity(1 - progress)
        } else {
            return to.opacity(progress)
        }
    }
}

// MARK: - Weather Time Background

struct MaWeatherTimeBackground: View {
    /// The time to display (usually current time or scrolled time)
    let displayTime: Date

    /// Weather condition (can be fetched from API or simulated)
    var weather: WeatherCondition = .clear

    @Environment(\.colorScheme) var colorScheme

    // Animation states
    @State private var cloudOffset: CGFloat = 0
    @State private var starTwinkle: Double = 0
    @State private var sunPulse: CGFloat = 0
    @State private var precipitationPhase: Double = 0

    private var calendar: Calendar { Calendar.current }

    private var hour: Int {
        calendar.component(.hour, from: displayTime)
    }

    private var minute: Int {
        calendar.component(.minute, from: displayTime)
    }

    private var timePeriodInfo: (progress: Double, current: TimePeriod, next: TimePeriod) {
        TimePeriod.progressAndNext(hour: hour, minute: minute)
    }

    private var isNightTime: Bool {
        let period = timePeriodInfo.current
        return period == .night || period == .lateNight || period == .dusk
    }

    private var showSun: Bool {
        let period = timePeriodInfo.current
        return period == .morning || period == .afternoon || period == .dawn || period == .evening
    }

    private var showMoon: Bool {
        isNightTime
    }

    private var showStars: Bool {
        isNightTime && weather != .cloudy && weather != .rainy
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base sky gradient
                skyGradient

                // Stars layer (night only)
                if showStars {
                    StarsLayer(twinklePhase: starTwinkle, density: starDensity)
                        .opacity(starOpacity)
                }

                // Celestial body (sun or moon)
                if showSun {
                    SunView(
                        period: timePeriodInfo.current,
                        progress: timePeriodInfo.progress,
                        pulsePhase: sunPulse,
                        screenSize: geometry.size
                    )
                    .opacity(sunOpacity)
                }

                if showMoon {
                    MoonView(
                        period: timePeriodInfo.current,
                        progress: timePeriodInfo.progress,
                        screenSize: geometry.size
                    )
                    .opacity(moonOpacity)
                }

                // Cloud layers
                if weather.cloudDensity > 0 {
                    CloudsLayer(
                        density: weather.cloudDensity,
                        offset: cloudOffset,
                        colorScheme: colorScheme,
                        isNight: isNightTime
                    )
                }

                // Precipitation layer
                if weather.hasPrecipitation {
                    PrecipitationLayer(
                        type: weather == .snowy ? .snow : .rain,
                        phase: precipitationPhase,
                        screenSize: geometry.size
                    )
                }

                // Ambient glow overlay
                ambientGlow
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Sky Gradient

    private var skyGradient: some View {
        let info = timePeriodInfo
        let currentPalette = SkyPalette.forPeriod(info.current, colorScheme: colorScheme)
        let nextPalette = SkyPalette.forPeriod(info.next, colorScheme: colorScheme)

        // Smooth transition in the last 20% of each period
        let transitionStart = 0.8
        let transitionProgress = info.progress > transitionStart
            ? (info.progress - transitionStart) / (1 - transitionStart)
            : 0

        let palette = transitionProgress > 0
            ? SkyPalette.interpolate(from: currentPalette, to: nextPalette, progress: transitionProgress)
            : currentPalette

        return LinearGradient(
            colors: [palette.topColor, palette.bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        let info = timePeriodInfo
        let palette = SkyPalette.forPeriod(info.current, colorScheme: colorScheme)

        return RadialGradient(
            colors: [
                palette.ambientColor,
                Color.clear
            ],
            center: ambientGlowCenter,
            startRadius: 50,
            endRadius: 400
        )
        .blendMode(.softLight)
    }

    private var ambientGlowCenter: UnitPoint {
        let period = timePeriodInfo.current
        switch period {
        case .dawn, .morning:
            return UnitPoint(x: 0.8, y: 0.3)
        case .afternoon:
            return UnitPoint(x: 0.5, y: 0.1)
        case .evening, .dusk:
            return UnitPoint(x: 0.2, y: 0.4)
        case .night, .lateNight:
            return UnitPoint(x: 0.7, y: 0.2)
        }
    }

    // MARK: - Opacity Calculations

    private var starOpacity: Double {
        let period = timePeriodInfo.current
        let progress = timePeriodInfo.progress

        switch period {
        case .night:
            return 0.8
        case .lateNight:
            return 0.7 - progress * 0.3
        case .dusk:
            return progress * 0.6
        case .dawn:
            return max(0, 0.5 - progress * 0.5)
        default:
            return 0
        }
    }

    private var starDensity: Double {
        weather == .cloudy ? 0.3 : 1.0
    }

    private var sunOpacity: Double {
        let period = timePeriodInfo.current
        let progress = timePeriodInfo.progress

        switch period {
        case .dawn:
            return 0.3 + progress * 0.4
        case .morning:
            return 0.7 + progress * 0.3
        case .afternoon:
            return 1.0 - progress * 0.1
        case .evening:
            return 0.9 - progress * 0.5
        default:
            return 0
        }
    }

    private var moonOpacity: Double {
        let period = timePeriodInfo.current
        let progress = timePeriodInfo.progress

        switch period {
        case .dusk:
            return progress * 0.6
        case .night:
            return 0.6 + progress * 0.2
        case .lateNight:
            return 0.8 - progress * 0.3
        default:
            return 0
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Cloud drift animation
        withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
            cloudOffset = 1.0
        }

        // Star twinkle
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            starTwinkle = 1.0
        }

        // Sun pulse
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            sunPulse = 1.0
        }

        // Precipitation
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            precipitationPhase = 1.0
        }
    }
}

// MARK: - Stars Layer

struct StarsLayer: View {
    let twinklePhase: Double
    let density: Double

    @State private var stars: [Star] = []

    var body: some View {
        Canvas { context, size in
            for star in stars {
                let twinkle = sin(twinklePhase * .pi * 2 + star.phase) * 0.3 + 0.7
                let opacity = star.brightness * twinkle * density

                context.opacity = opacity
                context.fill(
                    Circle().path(in: CGRect(
                        x: star.position.x * size.width - star.size / 2,
                        y: star.position.y * size.height - star.size / 2,
                        width: star.size,
                        height: star.size
                    )),
                    with: .color(.white)
                )
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        stars = (0..<80).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...0.6)  // Stars in upper portion
                ),
                size: CGFloat.random(in: 1...3),
                brightness: Double.random(in: 0.4...1.0),
                phase: Double.random(in: 0...(2 * .pi))
            )
        }
    }
}

struct Star {
    let position: CGPoint
    let size: CGFloat
    let brightness: Double
    let phase: Double
}

// MARK: - Sun View

struct SunView: View {
    let period: TimePeriod
    let progress: Double
    let pulsePhase: CGFloat
    let screenSize: CGSize

    private var sunPosition: CGPoint {
        // Sun moves across the sky based on time
        let xProgress: CGFloat
        let yProgress: CGFloat

        switch period {
        case .dawn:
            xProgress = 0.8 + CGFloat(progress) * 0.1
            yProgress = 0.5 - CGFloat(progress) * 0.2
        case .morning:
            xProgress = 0.9 - CGFloat(progress) * 0.4
            yProgress = 0.3 - CGFloat(progress) * 0.15
        case .afternoon:
            xProgress = 0.5 - CGFloat(progress) * 0.3
            yProgress = 0.15 + CGFloat(progress) * 0.2
        case .evening:
            xProgress = 0.2 - CGFloat(progress) * 0.1
            yProgress = 0.35 + CGFloat(progress) * 0.25
        default:
            xProgress = 0.5
            yProgress = 0.5
        }

        return CGPoint(
            x: screenSize.width * xProgress,
            y: screenSize.height * yProgress
        )
    }

    private var sunColor: Color {
        switch period {
        case .dawn:
            return Color(hex: "#FFB347")
        case .morning:
            return Color(hex: "#FFE4B5")
        case .afternoon:
            return Color(hex: "#FFFACD")
        case .evening:
            return Color(hex: "#FF8C42")
        default:
            return Color(hex: "#FFD700")
        }
    }

    private var glowColor: Color {
        sunColor.opacity(0.3)
    }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor, Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80 + pulsePhase * 10
                    )
                )
                .frame(width: 160, height: 160)

            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [sunColor.opacity(0.5), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)

            // Sun core
            Circle()
                .fill(sunColor)
                .frame(width: 24 + pulsePhase * 2, height: 24 + pulsePhase * 2)
                .blur(radius: 2)
        }
        .position(sunPosition)
    }
}

// MARK: - Moon View

struct MoonView: View {
    let period: TimePeriod
    let progress: Double
    let screenSize: CGSize

    @State private var glowPhase: CGFloat = 0

    private var moonPosition: CGPoint {
        let xProgress: CGFloat
        let yProgress: CGFloat

        switch period {
        case .dusk:
            xProgress = 0.8 - CGFloat(progress) * 0.1
            yProgress = 0.3 + CGFloat(progress) * 0.1
        case .night:
            xProgress = 0.7 - CGFloat(progress) * 0.3
            yProgress = 0.2 + CGFloat(progress) * 0.05
        case .lateNight:
            xProgress = 0.4 - CGFloat(progress) * 0.2
            yProgress = 0.25 + CGFloat(progress) * 0.1
        default:
            xProgress = 0.3
            yProgress = 0.2
        }

        return CGPoint(
            x: screenSize.width * xProgress,
            y: screenSize.height * yProgress
        )
    }

    var body: some View {
        ZStack {
            // Moon glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 60 + glowPhase * 5
                    )
                )
                .frame(width: 120, height: 120)

            // Moon surface
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#F5F5DC"),
                            Color(hex: "#E8E8D0")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    // Subtle crater details
                    Circle()
                        .fill(Color(hex: "#D8D8C0").opacity(0.3))
                        .frame(width: 6, height: 6)
                        .offset(x: 4, y: -4)
                )
                .overlay(
                    Circle()
                        .fill(Color(hex: "#D8D8C0").opacity(0.2))
                        .frame(width: 4, height: 4)
                        .offset(x: -5, y: 5)
                )
        }
        .position(moonPosition)
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
        }
    }
}

// MARK: - Clouds Layer

struct CloudsLayer: View {
    let density: Double
    let offset: CGFloat
    let colorScheme: ColorScheme
    let isNight: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background cloud layer (slower, further)
                ForEach(0..<3, id: \.self) { index in
                    CloudShape(seed: index * 100)
                        .fill(cloudColor.opacity(0.15 * density))
                        .frame(width: geometry.size.width * 0.6, height: 60)
                        .offset(
                            x: cloudXOffset(index: index, layer: 0, width: geometry.size.width),
                            y: CGFloat(index) * 50 + 40
                        )
                        .blur(radius: 20)
                }

                // Foreground cloud layer (faster, closer)
                ForEach(0..<4, id: \.self) { index in
                    CloudShape(seed: index * 50 + 25)
                        .fill(cloudColor.opacity(0.2 * density))
                        .frame(width: geometry.size.width * 0.5, height: 40)
                        .offset(
                            x: cloudXOffset(index: index, layer: 1, width: geometry.size.width),
                            y: CGFloat(index) * 40 + 80
                        )
                        .blur(radius: 15)
                }
            }
        }
    }

    private var cloudColor: Color {
        if isNight {
            return colorScheme == .dark
                ? Color(hex: "#2A3040")
                : Color(hex: "#404858")
        } else {
            return colorScheme == .dark
                ? Color(hex: "#3A4050")
                : Color.white
        }
    }

    private func cloudXOffset(index: Int, layer: Int, width: CGFloat) -> CGFloat {
        let baseOffset = CGFloat(index) * width * 0.3
        let layerSpeed = layer == 0 ? 0.5 : 1.0
        let animatedOffset = offset * width * CGFloat(layerSpeed)
        return (baseOffset + animatedOffset).truncatingRemainder(dividingBy: width * 1.5) - width * 0.25
    }
}

struct CloudShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Create organic cloud shape with multiple overlapping ellipses
        let random = SeededRandom(seed: seed)
        let blobCount = 4 + seed % 3

        for i in 0..<blobCount {
            let xRatio = CGFloat(i) / CGFloat(blobCount - 1)
            let x = rect.minX + rect.width * xRatio
            let y = rect.midY + CGFloat(random.next()) * rect.height * 0.2 - rect.height * 0.1
            let width = rect.width * (0.3 + CGFloat(random.next()) * 0.2)
            let height = rect.height * (0.5 + CGFloat(random.next()) * 0.4)

            path.addEllipse(in: CGRect(
                x: x - width / 2,
                y: y - height / 2,
                width: width,
                height: height
            ))
        }

        return path
    }
}

// Simple seeded random for consistent cloud shapes
struct SeededRandom {
    var seed: Int

    mutating func next() -> Double {
        seed = seed &* 1103515245 &+ 12345
        return Double((seed >> 16) & 0x7FFF) / Double(0x7FFF)
    }
}

// MARK: - Precipitation Layer

enum PrecipitationType {
    case rain
    case snow
}

struct PrecipitationLayer: View {
    let type: PrecipitationType
    let phase: Double
    let screenSize: CGSize

    @State private var particles: [PrecipitationParticle] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince1970

                for particle in particles {
                    let animatedY = (particle.startY + CGFloat(time * particle.speed * 50))
                        .truncatingRemainder(dividingBy: size.height + 50)
                    let animatedX = particle.x + sin(time * particle.wobble) * particle.wobbleAmount

                    if type == .rain {
                        // Draw rain drop
                        var rainPath = Path()
                        rainPath.move(to: CGPoint(x: animatedX, y: animatedY))
                        rainPath.addLine(to: CGPoint(x: animatedX, y: animatedY + particle.size))

                        context.stroke(
                            rainPath,
                            with: .color(.white.opacity(particle.opacity * 0.3)),
                            lineWidth: 1
                        )
                    } else {
                        // Draw snowflake
                        context.opacity = particle.opacity * 0.6
                        context.fill(
                            Circle().path(in: CGRect(
                                x: animatedX - particle.size / 2,
                                y: animatedY - particle.size / 2,
                                width: particle.size,
                                height: particle.size
                            )),
                            with: .color(.white)
                        )
                    }
                }
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        let count = type == .rain ? 100 : 60
        particles = (0..<count).map { _ in
            PrecipitationParticle(
                x: CGFloat.random(in: 0...screenSize.width),
                startY: CGFloat.random(in: -50...screenSize.height),
                size: type == .rain
                    ? CGFloat.random(in: 10...25)
                    : CGFloat.random(in: 2...5),
                speed: type == .rain
                    ? Double.random(in: 3...6)
                    : Double.random(in: 0.5...1.5),
                opacity: Double.random(in: 0.3...0.8),
                wobble: Double.random(in: 1...3),
                wobbleAmount: type == .snow ? CGFloat.random(in: 10...30) : 0
            )
        }
    }
}

struct PrecipitationParticle {
    let x: CGFloat
    let startY: CGFloat
    let size: CGFloat
    let speed: Double
    let opacity: Double
    let wobble: Double
    let wobbleAmount: CGFloat
}

// MARK: - Preview

#Preview("Weather Time Background - Morning") {
    MaWeatherTimeBackground(
        displayTime: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date())!,
        weather: .partlyCloudy
    )
    .ignoresSafeArea()
}

#Preview("Weather Time Background - Evening") {
    MaWeatherTimeBackground(
        displayTime: Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!,
        weather: .clear
    )
    .ignoresSafeArea()
}

#Preview("Weather Time Background - Night") {
    MaWeatherTimeBackground(
        displayTime: Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!,
        weather: .clear
    )
    .ignoresSafeArea()
}

#Preview("Weather Time Background - Rainy") {
    MaWeatherTimeBackground(
        displayTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
        weather: .rainy
    )
    .ignoresSafeArea()
}

#Preview("Weather Time Background - Snowy Night") {
    MaWeatherTimeBackground(
        displayTime: Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date())!,
        weather: .snowy
    )
    .ignoresSafeArea()
}
