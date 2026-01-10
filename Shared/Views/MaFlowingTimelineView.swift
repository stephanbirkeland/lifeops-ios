// MaFlowingTimelineView.swift
// A zen-like flowing timeline that moves at the pace of time
//
// Ma (間) - The space to breathe
//
// Design Philosophy:
// - Vertical timeline in center of screen
// - Events flow down slowly (synced to clock seconds)
// - Tasks within next hour appear at top, drift down
// - Tasks pile up gently at bottom when due
// - No clutter, no stress - just gentle awareness

import SwiftUI
import Combine

// MARK: - Icon Helper View

/// Displays either an SF Symbol or emoji text based on the icon string
struct MaIconView: View {
    let icon: String?
    let fallback: String
    let size: CGFloat
    let color: Color

    init(icon: String?, fallback: String = "circle", size: CGFloat = 24, color: Color = .primary) {
        self.icon = icon
        self.fallback = fallback
        self.size = size
        self.color = color
    }

    var body: some View {
        if let icon = icon, !icon.isEmpty {
            if isEmoji(icon) {
                // Display emoji as text
                Text(icon)
                    .font(.system(size: size * 0.9))
            } else if isSFSymbol(icon) {
                // Display as SF Symbol
                Image(systemName: icon)
                    .font(.system(size: size))
                    .foregroundStyle(color)
            } else {
                // Unknown format, show as text
                Text(icon)
                    .font(.system(size: size * 0.8))
            }
        } else {
            // Fallback SF Symbol
            Image(systemName: fallback)
                .font(.system(size: size))
                .foregroundStyle(color)
        }
    }

    /// Check if string starts with an emoji
    private func isEmoji(_ string: String) -> Bool {
        guard let firstScalar = string.unicodeScalars.first else { return false }
        return firstScalar.properties.isEmoji && firstScalar.properties.isEmojiPresentation
    }

    /// Check if string looks like an SF Symbol name (lowercase, dots, periods)
    private func isSFSymbol(_ string: String) -> Bool {
        let sfSymbolPattern = string.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
        return sfSymbolPattern && !string.isEmpty
    }
}

// MARK: - Flowing Timeline View

struct MaFlowingTimelineView: View {
    @StateObject private var viewModel = FlowingTimelineViewModel()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showCompletionCelebration = false
    @State private var completedItemPosition: CGPoint = .zero

    // Gesture state for time scrubbing
    @GestureState private var scrubDragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Weather and time-aware background
                MaWeatherTimeBackground(
                    displayTime: viewModel.displayTime,
                    weather: viewModel.currentWeather
                )
                .ignoresSafeArea()

                // Loading state (first load only)
                if viewModel.isLoading && viewModel.flowingItems.isEmpty && viewModel.piledUpItems.isEmpty {
                    MaLoadingView("Loading your timeline...")
                }
                // Error state (only show full error if we have no data)
                else if let error = viewModel.error, viewModel.flowingItems.isEmpty && viewModel.piledUpItems.isEmpty {
                    MaErrorView(error: error) {
                        viewModel.retry()
                    }
                }
                else {
                    // Main content - always show timeline

                // Central timeline with gradient glow
                MaEnhancedTimelinePath(screenHeight: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Flowing events with enhanced animations
                ForEach(viewModel.flowingItems) { item in
                    Group {
                        if item.isDurationEvent {
                            // Duration events (sleep, long tasks) as vertical bars
                            if item.isSleepEvent {
                                MaSleepEventBar(
                                    item: item,
                                    startY: item.currentY,
                                    endY: item.endY
                                )
                                .position(
                                    x: geometry.size.width / 2 + 80, // Offset to the right of timeline
                                    y: item.currentY + (item.endY - item.currentY) / 2
                                )
                                .onTapGesture { viewModel.selectItem(item) }
                            } else {
                                MaDurationEventBar(
                                    item: item,
                                    startY: item.currentY,
                                    endY: item.endY,
                                    screenWidth: geometry.size.width
                                )
                                .position(
                                    x: geometry.size.width / 2 + 80, // Offset to the right of timeline
                                    y: item.currentY + (item.endY - item.currentY) / 2
                                )
                                .onTapGesture { viewModel.selectItem(item) }
                            }
                        } else {
                            // Regular items as bubbles
                            MaEnhancedFlowingBubble(
                                item: item,
                                screenHeight: geometry.size.height,
                                onTap: { viewModel.selectItem(item) }
                            )
                            .position(
                                x: geometry.size.width / 2 + item.horizontalOffset,
                                y: item.currentY
                            )
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .modifier(
                            active: BubbleEntranceModifier(isActive: true),
                            identity: BubbleEntranceModifier(isActive: false)
                        ),
                        removal: .modifier(
                            active: BubbleExitModifier(isActive: true),
                            identity: BubbleExitModifier(isActive: false)
                        )
                    ))
                }

                // Time indicator - shows scrubbed time when scrubbing
                MaScrubTimeIndicator(
                    displayTime: viewModel.displayTime,
                    isScrubbing: viewModel.isScrubbing,
                    scrubOffset: viewModel.scrubOffset
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.7)

                // Piled up tasks and recently completed at bottom
                VStack(spacing: MaSpacing.md) {
                    Spacer()

                    // Recently completed items (visible for 15 minutes)
                    if !viewModel.recentlyCompletedItems.isEmpty {
                        MaRecentlyCompletedSection(items: viewModel.recentlyCompletedItems)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Piled up tasks
                    if !viewModel.piledUpItems.isEmpty {
                        MaEnhancedTaskPile(
                            items: viewModel.piledUpItems,
                            onComplete: { item in
                                completedItemPosition = CGPoint(
                                    x: geometry.size.width / 2,
                                    y: geometry.size.height - 100
                                )
                                viewModel.completeItem(item)
                                triggerCompletionCelebration()
                            },
                            onPostpone: viewModel.postponeItem,
                            onBundle: {
                                viewModel.bundleQuickTasks()
                                triggerCompletionCelebration()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    // Subtle empty state when no items - shows at bottom of timeline
                    else if viewModel.flowingItems.isEmpty && viewModel.recentlyCompletedItems.isEmpty {
                        MaSubtleEmptyState()
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, MaSpacing.lg)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.recentlyCompletedItems.count)

                // Top header with flowing time display
                VStack {
                    MaScrubFlowingHeader(
                        displayTime: viewModel.displayTime,
                        isScrubbing: viewModel.isScrubbing,
                        onTapReset: { viewModel.resetToCurrentTime() }
                    )
                    Spacer()
                }

                // Scrub hint overlay when not scrubbing
                if !viewModel.isScrubbing {
                    VStack {
                        Spacer()
                        MaScrubHint()
                            .padding(.bottom, 120)
                    }
                    .allowsHitTesting(false)
                }

                // Completion celebration overlay
                if showCompletionCelebration {
                    MaFlowingCompletionCelebration(position: completedItemPosition)
                        .allowsHitTesting(false)
                }
                } // End of else block for main content

                // Error banner for background refresh failures
                if viewModel.showErrorBanner, let error = viewModel.error {
                    VStack {
                        MaErrorBanner(
                            error: error,
                            onDismiss: { viewModel.dismissError() },
                            onRetry: { viewModel.retry() }
                        )
                        .padding(.horizontal, MaSpacing.md)
                        .padding(.top, 100)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: viewModel.showErrorBanner)
                }

                // Offline banner at top
                if !networkMonitor.isConnected {
                    VStack {
                        MaOfflineBanner()
                        Spacer()
                    }
                }
            }
            // Time scrubbing gesture
            .gesture(
                DragGesture()
                    .updating($scrubDragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onChanged { value in
                        let delta = value.translation.height - lastDragValue
                        viewModel.scrubTime(delta: delta)
                        lastDragValue = value.translation.height
                    }
                    .onEnded { _ in
                        lastDragValue = 0
                        viewModel.endScrubbing()
                    }
            )
        }
        .sheet(item: $viewModel.selectedItem) { item in
            MaFlowingItemDetailSheet(
                item: item,
                onComplete: { viewModel.completeItem(item) },
                onPostpone: { viewModel.postponeItem(item) },
                onSkip: { viewModel.skipItem(item) }
            )
        }
        .toast(
            isPresented: $viewModel.showToast,
            message: viewModel.toastMessage ?? "",
            style: viewModel.toastStyle
        )
        .onAppear {
            viewModel.startFlowing()
        }
        .onDisappear {
            viewModel.stopFlowing()
        }
    }

    private func triggerCompletionCelebration() {
        withAnimation(.easeOut(duration: 0.3)) {
            showCompletionCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                showCompletionCelebration = false
            }
        }
    }
}

// MARK: - Flowing Background

struct MaFlowingBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base color
            MaColors.background

            // Subtle animated gradient waves
            GeometryReader { geo in
                Canvas { context, size in
                    // Gentle wave pattern
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height * 0.3))
                        for x in stride(from: 0, through: size.width, by: 10) {
                            let y = size.height * 0.3 + sin((x / size.width) * .pi * 2 + phase) * 20
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.addLine(to: CGPoint(x: size.width, y: 0))
                        p.addLine(to: CGPoint(x: 0, y: 0))
                        p.closeSubpath()
                    }

                    context.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                colorScheme == .dark
                                    ? Color(hex: "#1F2428").opacity(0.3)
                                    : Color(hex: "#E8F4F8").opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height * 0.5)
                        )
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Enhanced Timeline Path

struct MaEnhancedTimelinePath: View {
    let screenHeight: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @State private var glowPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Outer glow layer
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            MaColors.primarySoft.opacity(0.0),
                            MaColors.primarySoft.opacity(0.1 + glowPhase * 0.05),
                            MaColors.primarySoft.opacity(0.15 + glowPhase * 0.05),
                            MaColors.primarySoft.opacity(0.1 + glowPhase * 0.05),
                            MaColors.primarySoft.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40)
                .blur(radius: 15)

            // Main timeline with gradient
            Rectangle()
                .fill(
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
                )
                .frame(width: 2)

            // Flowing particles along the timeline
            TimelineParticles(screenHeight: screenHeight)
        }
        .frame(height: screenHeight)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
        }
    }
}

// MARK: - Timeline Particles

struct TimelineParticles: View {
    let screenHeight: CGFloat
    @State private var particles: [FlowingParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(MaColors.primaryLight.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .offset(y: particle.y - screenHeight / 2)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            startParticleFlow()
        }
    }

    private func startParticleFlow() {
        // Create initial particles
        for i in 0..<5 {
            let delay = Double(i) * 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                addParticle()
            }
        }

        // Continue adding particles
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            addParticle()
        }
    }

    private func addParticle() {
        let particle = FlowingParticle(
            id: UUID(),
            y: -50,
            size: CGFloat.random(in: 3...6),
            opacity: Double.random(in: 0.3...0.6),
            speed: CGFloat.random(in: 30...50)
        )
        particles.append(particle)

        // Animate particle down
        withAnimation(.linear(duration: Double(screenHeight / particle.speed))) {
            if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                particles[index].y = screenHeight + 50
            }
        }

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(screenHeight / particle.speed)) {
            particles.removeAll { $0.id == particle.id }
        }
    }
}

struct FlowingParticle: Identifiable {
    let id: UUID
    var y: CGFloat
    let size: CGFloat
    let opacity: Double
    let speed: CGFloat
}

// MARK: - Scrub Time Indicator

struct MaScrubTimeIndicator: View {
    let displayTime: Date
    let isScrubbing: Bool
    let scrubOffset: TimeInterval

    @State private var breathePhase: CGFloat = 0
    @State private var innerGlow: CGFloat = 0

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: displayTime)
    }

    private var offsetLabel: String {
        if scrubOffset == 0 {
            return "now"
        } else if scrubOffset > 0 {
            let hours = Int(scrubOffset / 3600)
            let minutes = Int((scrubOffset.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                return "+\(hours)h \(minutes)m"
            }
            return "+\(minutes)m"
        } else {
            let hours = Int(-scrubOffset / 3600)
            let minutes = Int((-scrubOffset.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                return "-\(hours)h \(minutes)m"
            }
            return "-\(minutes)m"
        }
    }

    private var indicatorColor: Color {
        if isScrubbing {
            return MaColors.postpone // Amber when scrubbing
        }
        return MaColors.primaryLight
    }

    var body: some View {
        ZStack {
            // Outer breathing ring
            Circle()
                .stroke(
                    indicatorColor.opacity(0.2),
                    lineWidth: 2
                )
                .frame(width: 40 + breathePhase * 8, height: 40 + breathePhase * 8)
                .opacity(1.0 - breathePhase * 0.5)

            // Middle glow - larger when scrubbing
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            indicatorColor.opacity(isScrubbing ? 0.5 : 0.3),
                            indicatorColor.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: isScrubbing ? 35 : 25
                    )
                )
                .frame(width: isScrubbing ? 70 : 50, height: isScrubbing ? 70 : 50)
                .scaleEffect(1 + innerGlow * 0.1)

            // Inner dot with subtle pulse
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            indicatorColor
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: isScrubbing ? 18 : 14, height: isScrubbing ? 18 : 14)
                .shadow(color: indicatorColor.opacity(0.5), radius: isScrubbing ? 6 : 4)

            // Time/offset label
            HStack(spacing: 4) {
                if isScrubbing {
                    // Show time when scrubbing
                    Text(timeString)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    Text(offsetLabel)
                        .font(MaTypography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("now")
                        .font(MaTypography.caption)
                        .foregroundStyle(MaColors.textSecondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isScrubbing ? indicatorColor.opacity(0.9) : Color.clear)
            )
            .offset(x: isScrubbing ? 70 : 45)
            .opacity(0.7 + innerGlow * 0.3)
        }
        .animation(.spring(response: 0.3), value: isScrubbing)
        .onAppear {
            // Slow breathing animation
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathePhase = 1
            }
            // Subtle inner glow
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                innerGlow = 1
            }
        }
    }
}

// MARK: - Enhanced Time Indicator (Legacy - kept for compatibility)

struct MaEnhancedTimeIndicator: View {
    @State private var breathePhase: CGFloat = 0
    @State private var innerGlow: CGFloat = 0

    var body: some View {
        ZStack {
            // Outer breathing ring
            Circle()
                .stroke(
                    MaColors.primaryLight.opacity(0.2),
                    lineWidth: 2
                )
                .frame(width: 40 + breathePhase * 8, height: 40 + breathePhase * 8)
                .opacity(1.0 - breathePhase * 0.5)

            // Middle glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            MaColors.primaryLight.opacity(0.3),
                            MaColors.primarySoft.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
                .scaleEffect(1 + innerGlow * 0.1)

            // Inner dot with subtle pulse
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            MaColors.primaryLight
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: MaColors.primaryLight.opacity(0.5), radius: 4)

            // "Now" label with fade
            Text("now")
                .font(MaTypography.caption)
                .foregroundStyle(MaColors.textSecondary)
                .opacity(0.7 + innerGlow * 0.3)
                .offset(x: 45)
        }
        .onAppear {
            // Slow breathing animation
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathePhase = 1
            }
            // Subtle inner glow
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                innerGlow = 1
            }
        }
    }
}

// MARK: - Scrub Flowing Header

struct MaScrubFlowingHeader: View {
    let displayTime: Date
    let isScrubbing: Bool
    let onTapReset: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var colonOpacity: Double = 1

    // Determine if we need light text based on time of day
    private var needsLightText: Bool {
        let hour = Calendar.current.component(.hour, from: displayTime)
        // Dark backgrounds: night (0-5), dusk (19-21), late night (21-24)
        return hour < 6 || hour >= 19
    }

    private var textColor: Color {
        needsLightText ? .white : MaColors.textPrimary
    }

    private var secondaryTextColor: Color {
        needsLightText ? .white.opacity(0.7) : MaColors.textSecondary
    }

    private var scrubIndicatorColor: Color {
        isScrubbing ? MaColors.postpone : Color.clear
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MaSpacing.xxs) {
                // Time with breathing colon
                HStack(spacing: 0) {
                    Text(hourString)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(textColor)
                        .monospacedDigit()

                    Text(":")
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(textColor.opacity(colonOpacity))

                    Text(minuteString)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                }

                // Date or scrubbing indicator
                HStack(spacing: MaSpacing.xs) {
                    Text(dateString)
                        .font(MaTypography.bodyMedium)
                        .foregroundStyle(secondaryTextColor)

                    if isScrubbing {
                        // Scrubbing indicator badge
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                            Text("Scrubbing")
                                .font(MaTypography.caption)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(MaColors.postpone)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            Spacer()

            // Reset button when scrubbing, otherwise breathing leaf
            if isScrubbing {
                Button(action: onTapReset) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Now")
                    }
                    .font(MaTypography.labelSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(MaColors.primaryLight)
                    )
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                MaBreathingLeaf()
            }
        }
        .padding(.horizontal, MaSpacing.lg)
        .padding(.top, MaSpacing.lg)
        .background(
            // Subtle gradient for readability, adapts to time
            LinearGradient(
                colors: [
                    (needsLightText ? Color.black : Color.white).opacity(0.15),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .ignoresSafeArea()
        )
        .animation(.spring(response: 0.3), value: isScrubbing)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                colonOpacity = 0.3
            }
        }
    }

    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter.string(from: displayTime)
    }

    private var minuteString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        return formatter.string(from: displayTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: displayTime)
    }
}

// MARK: - Scrub Hint

struct MaScrubHint: View {
    @State private var opacity: Double = 0.5
    @State private var offset: CGFloat = 0

    var body: some View {
        HStack(spacing: MaSpacing.xs) {
            Image(systemName: "hand.draw")
                .font(.caption)
            Text("Swipe to scroll through time")
                .font(MaTypography.caption)
        }
        .foregroundStyle(MaColors.textTertiary)
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            // Gentle pulsing animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                opacity = 0.3
                offset = -3
            }
        }
    }
}

// MARK: - Subtle Empty State (shows within timeline)

/// A subtle empty state that appears at the bottom of the timeline when no items are scheduled
/// Unlike MaEmptyStateView, this doesn't replace the timeline - it's part of it
struct MaSubtleEmptyState: View {
    @State private var breathePhase: CGFloat = 0

    var body: some View {
        VStack(spacing: MaSpacing.md) {
            // Gentle animated circle
            ZStack {
                Circle()
                    .fill(MaColors.completeSoft.opacity(0.5))
                    .frame(width: 60 + breathePhase * 5, height: 60 + breathePhase * 5)

                Image(systemName: "leaf")
                    .font(.system(size: 24))
                    .foregroundStyle(MaColors.complete.opacity(0.7))
            }

            VStack(spacing: MaSpacing.xxs) {
                Text("All clear")
                    .font(MaTypography.labelMedium)
                    .foregroundStyle(MaColors.textSecondary)

                Text("Enjoy the moment")
                    .font(MaTypography.caption)
                    .foregroundStyle(MaColors.textTertiary)
            }
        }
        .padding(.vertical, MaSpacing.lg)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathePhase = 1
            }
        }
    }
}

// MARK: - Enhanced Flowing Header (Legacy)

struct MaEnhancedFlowingHeader: View {
    let currentTime: Date
    @Environment(\.colorScheme) var colorScheme
    @State private var colonOpacity: Double = 1

    // Determine if we need light text based on time of day
    private var needsLightText: Bool {
        let hour = Calendar.current.component(.hour, from: currentTime)
        // Dark backgrounds: night (0-5), dusk (19-21), late night (21-24)
        return hour < 6 || hour >= 19
    }

    private var textColor: Color {
        needsLightText ? .white : MaColors.textPrimary
    }

    private var secondaryTextColor: Color {
        needsLightText ? .white.opacity(0.7) : MaColors.textSecondary
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MaSpacing.xxs) {
                // Time with breathing colon
                HStack(spacing: 0) {
                    Text(hourString)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(textColor)
                        .monospacedDigit()

                    Text(":")
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(textColor.opacity(colonOpacity))

                    Text(minuteString)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                }

                Text(dateString)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer()

            // Zen leaf with gentle sway
            MaBreathingLeaf()
        }
        .padding(.horizontal, MaSpacing.lg)
        .padding(.top, MaSpacing.lg)
        .background(
            // Subtle gradient for readability, adapts to time
            LinearGradient(
                colors: [
                    (needsLightText ? Color.black : Color.white).opacity(0.15),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .ignoresSafeArea()
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                colonOpacity = 0.3
            }
        }
    }

    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter.string(from: currentTime)
    }

    private var minuteString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        return formatter.string(from: currentTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentTime)
    }
}

// MARK: - Breathing Leaf

struct MaBreathingLeaf: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: "leaf")
            .font(.title2)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        MaColors.complete.opacity(0.4),
                        MaColors.primaryLight.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    rotation = 5
                }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    scale = 1.05
                }
            }
    }
}

// MARK: - Duration Event Bar (Sleep & Long Events)

struct MaDurationEventBar: View {
    let item: FlowingItem
    let startY: CGFloat
    let endY: CGFloat
    let screenWidth: CGFloat

    @State private var shimmerPhase: CGFloat = 0
    @State private var glowPulse: CGFloat = 0

    private var barColor: Color {
        if item.isSleepEvent {
            return Color(hex: "#5C6BC0") // Indigo for sleep
        }
        return item.color
    }

    private var barHeight: CGFloat {
        max(abs(endY - startY), 60) // Minimum height of 60
    }

    private var iconName: String {
        if item.isSleepEvent {
            return "moon.zzz.fill"
        }
        return item.timelineItem.icon ?? "clock.fill"
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Glowing bar background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            barColor.opacity(0.15),
                            barColor.opacity(0.25),
                            barColor.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 52, height: barHeight)
                .overlay(
                    // Animated shimmer
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0)
                                ],
                                startPoint: UnitPoint(x: 0.5, y: shimmerPhase - 0.3),
                                endPoint: UnitPoint(x: 0.5, y: shimmerPhase + 0.3)
                            )
                        )
                )
                .overlay(
                    // Border with gradient
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    barColor.opacity(0.6),
                                    barColor.opacity(0.3),
                                    barColor.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: barColor.opacity(0.3), radius: 8 + glowPulse * 4, y: 0)

            // Top content - Icon and title
            VStack(spacing: 4) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(barColor.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .blur(radius: 4)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [barColor, barColor.opacity(0.7)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 14
                            )
                        )
                        .frame(width: 28, height: 28)

                    MaIconView(
                        icon: iconName,
                        fallback: "clock.fill",
                        size: 14,
                        color: .white
                    )
                }
                .padding(.top, 8)

                // Title - rotated for vertical reading
                if barHeight > 120 {
                    Text(item.title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(MaColors.textPrimary)
                        .lineLimit(1)
                        .frame(width: barHeight - 80)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .offset(y: (barHeight - 80) / 2 - 10)
                }
            }

            // Duration label at bottom
            VStack {
                Spacer()

                Text(item.durationText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(barColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(MaColors.backgroundSecondary.opacity(0.9))
                    )
                    .padding(.bottom, 8)
            }
            .frame(height: barHeight)

            // Start time indicator at top
            if let startTime = item.scheduledTime {
                HStack(spacing: 2) {
                    Text(formatTime(startTime))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(MaColors.textSecondary)
                }
                .offset(x: -40, y: 12)
            }

            // End time indicator at bottom
            if let endTime = item.endTime {
                HStack(spacing: 2) {
                    Text(formatTime(endTime))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(MaColors.textSecondary)
                }
                .offset(x: -40, y: barHeight - 12)
            }
        }
        .opacity(item.opacity)
        .onAppear {
            // Slow shimmer animation
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
            // Gentle glow pulse
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Sleep Event Special Bar

struct MaSleepEventBar: View {
    let item: FlowingItem
    let startY: CGFloat
    let endY: CGFloat

    @State private var starTwinkle: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var moonGlow: CGFloat = 0

    private var barHeight: CGFloat {
        max(abs(endY - startY), 80)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Night sky gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1a237e").opacity(0.4), // Deep indigo
                            Color(hex: "#311b92").opacity(0.3), // Deep purple
                            Color(hex: "#4a148c").opacity(0.25) // Purple
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: barHeight)
                .overlay(
                    // Stars
                    ZStack {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: "sparkle")
                                .font(.system(size: 6 + CGFloat(i % 3) * 2))
                                .foregroundStyle(.white.opacity(0.4 + starTwinkle[i] * 0.4))
                                .offset(
                                    x: CGFloat.random(in: -20...20),
                                    y: CGFloat(i) * (barHeight / 6) - barHeight / 3
                                )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#5C6BC0").opacity(0.6),
                                    Color(hex: "#7986CB").opacity(0.4),
                                    Color(hex: "#5C6BC0").opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(hex: "#5C6BC0").opacity(0.4), radius: 10 + moonGlow * 5, y: 0)

            // Moon and Zzz icon
            VStack(spacing: 6) {
                ZStack {
                    // Moon glow
                    Circle()
                        .fill(Color(hex: "#FFE082").opacity(0.3))
                        .frame(width: 40, height: 40)
                        .blur(radius: 8)
                        .scaleEffect(1 + moonGlow * 0.2)

                    // Moon
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FFE082"), Color(hex: "#FFC107")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 12)

                // Sleep label
                Text("Sleep")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Duration at bottom
            VStack {
                Spacer()

                Text(item.durationText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "#B39DDB"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#1a237e").opacity(0.8))
                    )
                    .padding(.bottom, 10)
            }
            .frame(height: barHeight)

            // Time labels
            if let startTime = item.scheduledTime {
                Text(formatTime(startTime))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#B39DDB").opacity(0.8))
                    .offset(x: -45, y: 10)
            }

            if let endTime = item.endTime {
                Text(formatTime(endTime))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#B39DDB").opacity(0.8))
                    .offset(x: -45, y: barHeight - 10)
            }
        }
        .opacity(item.opacity)
        .onAppear {
            // Star twinkle animations
            for i in 0..<5 {
                withAnimation(.easeInOut(duration: Double.random(in: 1.5...3)).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                    starTwinkle[i] = 1
                }
            }
            // Moon glow
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                moonGlow = 1
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Enhanced Flowing Event Bubble

struct MaEnhancedFlowingBubble: View {
    let item: FlowingItem
    let screenHeight: CGFloat
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var shimmer: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MaSpacing.sm) {
                // Glowing color indicator
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .blur(radius: 4)

                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                }

                // Title with soft shadow
                Text(item.title)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textPrimary)
                    .lineLimit(1)

                // Time badge
                if let time = item.scheduledTime {
                    Text(formatTime(time))
                        .font(MaTypography.caption)
                        .foregroundStyle(MaColors.textTertiary)
                        .padding(.horizontal, MaSpacing.xs)
                        .padding(.vertical, MaSpacing.xxxs)
                        .background(
                            Capsule()
                                .fill(MaColors.backgroundTertiary.opacity(0.5))
                        )
                }

                // Streak badge with flame animation
                if item.streak > 0 {
                    MaAnimatedStreakBadge(count: item.streak)
                }
            }
            .padding(.horizontal, MaSpacing.md)
            .padding(.vertical, MaSpacing.sm)
            .background(
                ZStack {
                    // Main background
                    Capsule()
                        .fill(MaColors.backgroundSecondary)

                    // Subtle shimmer effect
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0)
                                ],
                                startPoint: UnitPoint(x: shimmer - 0.3, y: 0),
                                endPoint: UnitPoint(x: shimmer + 0.3, y: 1)
                            )
                        )
                        .opacity(colorScheme == .dark ? 0.3 : 0.5)
                }
                .shadow(
                    color: colorScheme == .dark
                        ? Color.clear
                        : item.color.opacity(0.15),
                    radius: isPressed ? 4 : 8,
                    y: isPressed ? 1 : 2
                )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                item.color.opacity(0.4),
                                item.color.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(MaBubbleButtonStyle())
        .opacity(item.opacity)
        .scaleEffect(item.scale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            // Occasional shimmer
            withAnimation(.linear(duration: 3).delay(Double.random(in: 0...5))) {
                shimmer = 1.5
            }
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = [item.title]

        if item.isOverdue {
            parts.insert("Overdue:", at: 0)
        }

        if let time = item.scheduledTime {
            parts.append("at \(formatTime(time))")
        }

        if item.streak > 0 {
            parts.append("\(item.streak) day streak")
        }

        return parts.joined(separator: ", ")
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Bubble Button Style

struct MaBubbleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Bubble Entrance Modifier

struct BubbleEntranceModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0 : 1)
            .scaleEffect(isActive ? 0.5 : 1)
            .blur(radius: isActive ? 5 : 0)
            .offset(y: isActive ? -30 : 0)
    }
}

// MARK: - Bubble Exit Modifier

struct BubbleExitModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0 : 1)
            .scaleEffect(isActive ? 0.8 : 1)
            .blur(radius: isActive ? 3 : 0)
            .offset(y: isActive ? 20 : 0)
    }
}

// MARK: - Flowing Item Detail Sheet

struct MaFlowingItemDetailSheet: View {
    let item: FlowingItem
    let onComplete: () -> Void
    let onPostpone: () -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                MaColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MaSpacing.xl) {
                        // Item header
                        VStack(spacing: MaSpacing.md) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(item.color.opacity(0.15))
                                    .frame(width: 80, height: 80)

                                MaIconView(
                                    icon: item.timelineItem.icon,
                                    fallback: "circle",
                                    size: 36,
                                    color: item.color
                                )
                            }

                            // Title
                            Text(item.title)
                                .font(MaTypography.titleLarge)
                                .foregroundStyle(MaColors.textPrimary)
                                .multilineTextAlignment(.center)

                            // Streak badge
                            if item.streak > 0 {
                                MaStreakBadge(streak: item.streak)
                            }

                            // Description
                            if let description = item.timelineItem.description {
                                Text(description)
                                    .font(MaTypography.bodyMedium)
                                    .foregroundStyle(MaColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }

                            // Scheduled time
                            if let time = item.scheduledTime {
                                HStack(spacing: MaSpacing.xxs) {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                    Text(time, style: .time)
                                        .font(MaTypography.labelSmall)
                                }
                                .foregroundStyle(MaColors.textTertiary)
                            }
                        }
                        .padding(MaSpacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: MaRadius.lg)
                                .fill(MaColors.backgroundSecondary)
                                .shadow(
                                    color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                                    radius: 8,
                                    y: 2
                                )
                        )

                        // Action buttons
                        VStack(spacing: MaSpacing.md) {
                            // Complete button
                            Button {
                                onComplete()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Complete")
                                }
                                .font(MaTypography.labelLarge)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, MaSpacing.md)
                            }
                            .buttonStyle(MaPrimaryButtonStyle(color: MaColors.complete))

                            // Postpone button
                            Button {
                                onPostpone()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("Postpone")
                                }
                                .font(MaTypography.labelMedium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, MaSpacing.sm)
                            }
                            .buttonStyle(MaSecondaryButtonStyle())

                            // Skip button
                            Button {
                                onSkip()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "forward.fill")
                                    Text("Skip")
                                }
                                .font(MaTypography.labelMedium)
                                .foregroundStyle(MaColors.textSecondary)
                            }
                            .padding(.top, MaSpacing.sm)
                        }
                        .padding(MaSpacing.lg)
                    }
                    .padding(MaSpacing.md)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(MaColors.primaryLight)
                }
            }
        }
    }
}

// MARK: - Animated Streak Badge

struct MaAnimatedStreakBadge: View {
    let count: Int
    @State private var flameScale: CGFloat = 1
    @State private var flameOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: MaSpacing.xxxs) {
            Image(systemName: streakIcon)
                .foregroundStyle(MaGradients.flame)
                .scaleEffect(flameScale)
                .offset(y: flameOffset)

            Text("\(count)")
                .font(MaTypography.labelSmall)
                .foregroundStyle(MaColors.streak)
        }
        .padding(.horizontal, MaSpacing.xs)
        .padding(.vertical, MaSpacing.xxxs)
        .background(
            Capsule()
                .fill(MaColors.secondarySoft.opacity(0.5))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                flameScale = 1.1
                flameOffset = -1
            }
        }
    }

    private var streakIcon: String {
        count >= 30 ? "flame.fill" : "flame"
    }
}

// MARK: - Enhanced Task Pile

struct MaEnhancedTaskPile: View {
    let items: [FlowingItem]
    let onComplete: (FlowingItem) -> Void
    let onPostpone: (FlowingItem) -> Void
    let onBundle: () -> Void

    @State private var expandedPile = false
    @State private var gentlePulse: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    private var quickTasks: [FlowingItem] {
        items.filter { $0.estimatedMinutes <= 5 }
    }

    var body: some View {
        VStack(spacing: MaSpacing.sm) {
            // Quick tasks bundle
            if quickTasks.count >= 2 {
                MaEnhancedQuickBundle(
                    tasks: quickTasks,
                    onBundle: onBundle
                )
            }

            // Main pile
            if expandedPile {
                // Expanded view
                VStack(spacing: MaSpacing.xs) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        MaEnhancedPiledRow(
                            item: item,
                            onComplete: { onComplete(item) },
                            onPostpone: { onPostpone(item) }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        ))
                        .animation(.spring(response: 0.3).delay(Double(index) * 0.05), value: expandedPile)
                    }
                }
            } else {
                // Collapsed stacked view
                MaEnhancedStackedPile(
                    items: items,
                    onTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            expandedPile = true
                        }
                    }
                )
            }

            // Collapse button
            if expandedPile && items.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        expandedPile = false
                    }
                } label: {
                    HStack(spacing: MaSpacing.xs) {
                        Image(systemName: "chevron.up")
                        Text("Collapse")
                    }
                    .font(MaTypography.caption)
                    .foregroundStyle(MaColors.textTertiary)
                    .padding(.vertical, MaSpacing.xs)
                }
            }
        }
        .padding(.horizontal, MaSpacing.lg)
        .animation(.spring(response: 0.4), value: expandedPile)
    }
}

// MARK: - Recently Completed Section

struct MaRecentlyCompletedSection: View {
    let items: [CompletedItem]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: MaSpacing.sm) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MaColors.complete)
                Text("Recently Completed")
                    .font(MaTypography.labelSmall)
                    .foregroundStyle(MaColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, MaSpacing.sm)

            // Completed items
            ForEach(items) { item in
                MaCompletedItemRow(item: item)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .padding(MaSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MaRadius.lg)
                .fill(MaColors.completeSoft.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: MaRadius.lg)
                        .stroke(MaColors.complete.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, MaSpacing.lg)
    }
}

// MARK: - Completed Item Row

struct MaCompletedItemRow: View {
    let item: CompletedItem
    @State private var showXPDetails = false
    @State private var celebrationScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: MaSpacing.sm) {
            // Icon with checkmark overlay
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.2))
                    .frame(width: 32, height: 32)

                // Show item icon or checkmark
                if let icon = item.icon, !icon.isEmpty {
                    MaIconView(
                        icon: icon,
                        fallback: "checkmark",
                        size: 16,
                        color: item.color
                    )
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(item.color)
                }
            }
            .scaleEffect(celebrationScale)

            // Title and time
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textPrimary)
                    .strikethrough(true, color: MaColors.textTertiary.opacity(0.5))

                Text(item.timeSinceCompletion)
                    .font(MaTypography.caption)
                    .foregroundStyle(MaColors.textTertiary)
            }

            Spacer()

            // XP and Streak badges
            VStack(alignment: .trailing, spacing: 4) {
                // XP Badge
                if item.totalXP > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("+\(item.totalXP) XP")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(MaColors.xp)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(MaColors.xpSoft.opacity(0.5))
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            showXPDetails.toggle()
                        }
                    }
                }

                // Streak badge
                if item.newStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: item.newStreak >= 7 ? "flame.fill" : "flame")
                            .font(.system(size: 10))
                        Text("\(item.newStreak)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(MaColors.streak)
                }
            }
        }
        .padding(MaSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MaRadius.md)
                .fill(MaColors.backgroundSecondary)
        )
        .onAppear {
            // Celebration animation on appear
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                celebrationScale = 1.1
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
                celebrationScale = 1.0
            }
        }

        // XP Details popover
        if showXPDetails && !item.xpGranted.isEmpty {
            HStack(spacing: MaSpacing.xs) {
                ForEach(Array(item.xpGranted.keys.sorted()), id: \.self) { stat in
                    if let xp = item.xpGranted[stat] {
                        Text("\(stat): +\(xp)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(MaColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, MaSpacing.sm)
            .padding(.vertical, MaSpacing.xxs)
            .background(
                Capsule()
                    .fill(MaColors.backgroundTertiary)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Enhanced Stacked Pile

struct MaEnhancedStackedPile: View {
    let items: [FlowingItem]
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var attentionPulse: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Stacked background cards with depth
                ForEach(Array(items.prefix(3).enumerated().reversed()), id: \.element.id) { index, item in
                    RoundedRectangle(cornerRadius: MaRadius.lg)
                        .fill(MaColors.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: MaRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            item.color.opacity(0.4),
                                            item.color.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: colorScheme == .dark
                                ? Color.clear
                                : Color.black.opacity(0.05 - Double(index) * 0.01),
                            radius: 6 - CGFloat(index) * 2,
                            y: 2
                        )
                        .offset(y: CGFloat(index) * -6)
                        .scaleEffect(1 - CGFloat(index) * 0.03)
                        .opacity(1 - Double(index) * 0.15)
                }

                // Front card content
                if let frontItem = items.first {
                    HStack {
                        // Glowing dot
                        ZStack {
                            Circle()
                                .fill(frontItem.color.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .blur(radius: 4)
                                .scaleEffect(1 + attentionPulse * 0.2)

                            Circle()
                                .fill(frontItem.color)
                                .frame(width: 12, height: 12)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(frontItem.title)
                                .font(MaTypography.bodyMedium)
                                .foregroundStyle(MaColors.textPrimary)

                            if items.count > 1 {
                                Text("+\(items.count - 1) more waiting")
                                    .font(MaTypography.caption)
                                    .foregroundStyle(MaColors.textTertiary)
                            } else {
                                Text("Tap to expand")
                                    .font(MaTypography.caption)
                                    .foregroundStyle(MaColors.textTertiary)
                            }
                        }

                        Spacer()

                        // Gentle attention indicator
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        MaColors.postpone,
                                        MaColors.postpone.opacity(0.5)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 5
                                )
                            )
                            .frame(width: 10, height: 10)
                            .scaleEffect(1 + attentionPulse * 0.3)
                            .opacity(0.8 + attentionPulse * 0.2)
                    }
                    .padding(MaSpacing.md)
                }
            }
            .frame(height: 60)
        }
        .buttonStyle(MaPileButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                attentionPulse = 1
            }
        }
    }
}

// MARK: - Pile Button Style

struct MaPileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Piled Row

struct MaEnhancedPiledRow: View {
    let item: FlowingItem
    let onComplete: () -> Void
    let onPostpone: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isCompleting = false
    @State private var isPostponing = false

    var body: some View {
        HStack(spacing: MaSpacing.sm) {
            // Color indicator
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .blur(radius: 3)

                Circle()
                    .fill(item.color)
                    .frame(width: 10, height: 10)
            }

            // Title and waiting time
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textPrimary)

                Text(item.waitingTimeText)
                    .font(MaTypography.caption)
                    .foregroundStyle(item.needsReminder ? MaColors.postpone : MaColors.textTertiary)
            }

            Spacer()

            // Action buttons with micro-interactions
            HStack(spacing: MaSpacing.xs) {
                // Postpone button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isPostponing = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onPostpone()
                        isPostponing = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(MaColors.postponeSoft)
                            .frame(width: 36, height: 36)

                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))
                            .foregroundStyle(MaColors.postpone)
                            .rotationEffect(.degrees(isPostponing ? 360 : 0))
                    }
                }
                .buttonStyle(.plain)

                // Complete button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isCompleting = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                        isCompleting = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isCompleting ? MaColors.complete : MaColors.completeSoft)
                            .frame(width: 36, height: 36)
                            .scaleEffect(isCompleting ? 1.1 : 1.0)

                        Image(systemName: isCompleting ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: isCompleting ? 20 : 16))
                            .foregroundStyle(isCompleting ? .white : MaColors.complete)
                            .scaleEffect(isCompleting ? 1.2 : 1.0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MaSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MaRadius.md)
                .fill(MaColors.backgroundSecondary)
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                    radius: 4,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: MaRadius.md)
                .stroke(
                    LinearGradient(
                        colors: [
                            item.color.opacity(0.3),
                            item.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Enhanced Quick Bundle

struct MaEnhancedQuickBundle: View {
    let tasks: [FlowingItem]
    let onBundle: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var sparklePhase: CGFloat = 0

    var body: some View {
        Button(action: onBundle) {
            HStack(spacing: MaSpacing.sm) {
                // Overlapping task dots
                HStack(spacing: -6) {
                    ForEach(Array(tasks.prefix(4).enumerated()), id: \.element.id) { index, task in
                        ZStack {
                            Circle()
                                .fill(task.color.opacity(0.5))
                                .frame(width: 22, height: 22)
                                .blur(radius: 2)

                            Circle()
                                .fill(task.color)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(MaColors.backgroundSecondary, lineWidth: 2)
                                )
                        }
                        .zIndex(Double(4 - index))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(tasks.count) quick tasks")
                        .font(MaTypography.labelMedium)
                        .foregroundStyle(MaColors.textPrimary)

                    Text("Bundle & complete together")
                        .font(MaTypography.caption)
                        .foregroundStyle(MaColors.textTertiary)
                }

                Spacer()

                // Animated sparkles
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(MaColors.xp)
                        .scaleEffect(1 + sparklePhase * 0.1)

                    Circle()
                        .fill(MaColors.xp.opacity(0.2))
                        .frame(width: 30, height: 30)
                        .scaleEffect(sparklePhase)
                        .opacity(1 - sparklePhase)
                }
            }
            .padding(MaSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MaRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [
                                MaColors.xpSoft.opacity(0.5),
                                MaColors.xpSoft.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaRadius.lg)
                    .stroke(
                        LinearGradient(
                            colors: [
                                MaColors.xp.opacity(0.4),
                                MaColors.xp.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(MaPileButtonStyle())
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                sparklePhase = 1
            }
        }
    }
}

// MARK: - Flowing Completion Celebration

struct MaFlowingCompletionCelebration: View {
    let position: CGPoint
    @State private var particles: [CelebrationParticle] = []
    @State private var checkScale: CGFloat = 0
    @State private var ringScale: CGFloat = 0
    @State private var ringOpacity: Double = 1

    var body: some View {
        ZStack {
            // Expanding ring
            Circle()
                .stroke(MaColors.complete, lineWidth: 2)
                .frame(width: 60 * ringScale, height: 60 * ringScale)
                .opacity(ringOpacity)
                .position(position)

            // Celebration particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(
                        x: position.x + particle.offset.x,
                        y: position.y + particle.offset.y
                    )
                    .opacity(particle.opacity)
            }

            // Central checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(MaColors.complete)
                .scaleEffect(checkScale)
                .position(position)
        }
        .onAppear {
            // Animate checkmark
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                checkScale = 1
            }

            // Animate ring
            withAnimation(.easeOut(duration: 0.6)) {
                ringScale = 3
                ringOpacity = 0
            }

            // Create particles
            createParticles()
        }
    }

    private func createParticles() {
        let colors = [MaColors.complete, MaColors.xp, MaColors.primaryLight, MaColors.streak]

        for i in 0..<12 {
            let angle = (Double(i) / 12.0) * .pi * 2
            let particle = CelebrationParticle(
                id: UUID(),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...8),
                offset: .zero,
                opacity: 1
            )
            particles.append(particle)

            // Animate particle outward
            let targetX = cos(angle) * CGFloat.random(in: 50...100)
            let targetY = sin(angle) * CGFloat.random(in: 50...100)

            withAnimation(.easeOut(duration: 0.8).delay(Double(i) * 0.02)) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].offset = CGPoint(x: targetX, y: targetY)
                    particles[index].opacity = 0
                }
            }
        }
    }
}

struct CelebrationParticle: Identifiable {
    let id: UUID
    let color: Color
    let size: CGFloat
    var offset: CGPoint
    var opacity: Double
}

// MARK: - Flowing Item Model

struct FlowingItem: Identifiable {
    let id: String
    let code: String  // API identifier for complete/postpone/skip actions
    let title: String
    let scheduledTime: Date?
    let endTime: Date?
    let color: Color
    let streak: Int
    let estimatedMinutes: Int
    let timelineItem: TimelineFeedItem

    // Animation properties
    var currentY: CGFloat = 0
    var endY: CGFloat = 0 // For duration events
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var horizontalOffset: CGFloat = 0
    var arrivedAt: Date?

    // Enhanced animation state
    var entranceProgress: CGFloat = 0

    /// Whether this is a duration event (has significant length)
    var isDurationEvent: Bool {
        estimatedMinutes >= 30
    }

    /// Whether this is a sleep event
    var isSleepEvent: Bool {
        let category = timelineItem.category?.lowercased() ?? ""
        let title = timelineItem.title.lowercased()
        return category == "sleep" || title.contains("sleep") || title.contains("bed")
    }

    /// Whether this item is overdue
    var isOverdue: Bool {
        timelineItem.isOverdue
    }

    /// Duration in hours for display
    var durationHours: Double {
        Double(estimatedMinutes) / 60.0
    }

    /// Formatted duration text
    var durationText: String {
        if estimatedMinutes >= 60 {
            let hours = estimatedMinutes / 60
            let mins = estimatedMinutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(estimatedMinutes)m"
    }

    var waitingTimeText: String {
        guard let arrived = arrivedAt else { return "" }
        let minutes = Int(-arrived.timeIntervalSinceNow / 60)
        if minutes < 1 { return "Just arrived" }
        if minutes == 1 { return "Waiting 1 min" }
        return "Waiting \(minutes) mins"
    }

    var needsReminder: Bool {
        guard let arrived = arrivedAt else { return false }
        return -arrived.timeIntervalSinceNow >= 30 * 60 // 30 minutes
    }
}

// MARK: - Completed Item Model

struct CompletedItem: Identifiable {
    let id: String
    let title: String
    let completedAt: Date
    let xpGranted: [String: Int]
    let newStreak: Int
    let color: Color
    let icon: String?

    var totalXP: Int {
        xpGranted.values.reduce(0, +)
    }

    var timeSinceCompletion: String {
        let minutes = Int(-completedAt.timeIntervalSinceNow / 60)
        if minutes < 1 { return "Just now" }
        if minutes == 1 { return "1 min ago" }
        return "\(minutes) mins ago"
    }

    var isExpired: Bool {
        -completedAt.timeIntervalSinceNow >= 15 * 60 // 15 minutes
    }
}

// MARK: - Flowing Timeline ViewModel

import os.log

private let timelineLogger = Logger(subsystem: "com.lifeops.app", category: "Timeline")

@MainActor
class FlowingTimelineViewModel: ObservableObject {
    @Published var flowingItems: [FlowingItem] = []
    @Published var piledUpItems: [FlowingItem] = []
    @Published var recentlyCompletedItems: [CompletedItem] = []  // Items completed in last 15 mins
    @Published var currentTime = Date()
    @Published var selectedItem: FlowingItem?

    // Loading and error state
    @Published var isLoading = false
    @Published var error: APIError?
    @Published var showErrorBanner = false
    @Published var toastMessage: String?
    @Published var toastStyle: MaToast.Style = .info
    @Published var showToast = false

    // Time scrubbing state
    @Published var displayTime = Date()
    @Published var isScrubbing = false
    @Published var scrubOffset: TimeInterval = 0 // Offset in seconds from current time

    // Weather integration (simplified - can be replaced with WeatherKit later)
    @Published var currentWeather: WeatherCondition = .clear

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var flowTimer: Timer?
    private var scrubResetTimer: Timer?
    private let apiClient = APIClient.shared
    private var hasLoadedOnce = false

    // Screen dimensions
    private var screenHeight: CGFloat = UIScreen.main.bounds.height
    private let nowLineY: CGFloat = 0.7 // 70% down the screen
    private let topY: CGFloat = 100

    // Time scrubbing constants
    private let maxScrubOffset: TimeInterval = 12 * 3600 // 12 hours forward
    private let minScrubOffset: TimeInterval = -12 * 3600 // 12 hours backward
    private let scrubResetDelay: TimeInterval = 3.0 // 3 seconds to reset

    // Recently completed display duration
    private let recentlyCompletedDuration: TimeInterval = 15 * 60 // 15 minutes

    func startFlowing() {
        // Use CADisplayLink for smooth 60fps animations
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)

        // Fetch initial data
        Task {
            await loadTimeline()
        }

        // Refresh data every minute
        flowTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.loadTimeline()
            }
        }
    }

    func stopFlowing() {
        displayLink?.invalidate()
        displayLink = nil
        flowTimer?.invalidate()
        flowTimer = nil
        scrubResetTimer?.invalidate()
        scrubResetTimer = nil
    }

    @objc private func updateFrame(_ displayLink: CADisplayLink) {
        let currentFrameTime = displayLink.timestamp

        // Update time display once per second (only when not scrubbing)
        if currentFrameTime - lastUpdateTime >= 1.0 {
            currentTime = Date()
            if !isScrubbing {
                displayTime = currentTime
            }
            lastUpdateTime = currentFrameTime

            // Weather can be integrated with WeatherKit later
            // For now, weather stays as set (default .clear)

            // Clean up expired recently completed items (older than 15 minutes)
            cleanupExpiredCompletedItems()
        }

        // Smooth position updates every frame
        updateItemPositions()
    }

    /// Remove recently completed items that are older than 15 minutes
    private func cleanupExpiredCompletedItems() {
        let expiredItems = recentlyCompletedItems.filter { $0.isExpired }
        if !expiredItems.isEmpty {
            withAnimation(.easeOut(duration: 0.3)) {
                recentlyCompletedItems.removeAll { $0.isExpired }
            }
        }
    }

    // MARK: - Time Scrubbing

    /// Handle time scrubbing gesture
    /// - Parameter delta: The vertical drag delta (positive/down = future, negative/up = past)
    func scrubTime(delta: CGFloat) {
        isScrubbing = true

        // Convert pixel delta to time offset
        // Swipe down (positive delta) = move forward in time (future)
        // Swipe up (negative delta) = move backward in time (past)
        // 100 pixels = 1 hour
        let timeChange = TimeInterval(delta / 100.0 * 3600)
        scrubOffset = max(minScrubOffset, min(maxScrubOffset, scrubOffset + timeChange))

        // Update display time
        displayTime = currentTime.addingTimeInterval(scrubOffset)

        // Reset the auto-reset timer
        resetScrubTimer()
    }

    /// End scrubbing gesture
    func endScrubbing() {
        // Start the reset timer
        resetScrubTimer()
    }

    /// Reset to current time
    func resetToCurrentTime() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isScrubbing = false
            scrubOffset = 0
            displayTime = currentTime
        }
    }

    private func resetScrubTimer() {
        scrubResetTimer?.invalidate()
        scrubResetTimer = Timer.scheduledTimer(withTimeInterval: scrubResetDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resetToCurrentTime()
            }
        }
    }

    /// Get items visible at the current display time
    var visibleItems: [FlowingItem] {
        // Filter items based on display time
        // Show items scheduled within the visible time window
        let windowStart = displayTime.addingTimeInterval(-2 * 3600) // 2 hours before
        let windowEnd = displayTime.addingTimeInterval(2 * 3600) // 2 hours after

        return flowingItems.filter { item in
            guard let scheduledTime = item.scheduledTime else { return true }
            return scheduledTime >= windowStart && scheduledTime <= windowEnd
        }
    }

    /// Get items that are "piled up" at the display time
    var visiblePiledItems: [FlowingItem] {
        // Show items that would be due at the display time
        return piledUpItems.filter { item in
            guard let scheduledTime = item.scheduledTime else { return true }
            return scheduledTime <= displayTime
        }
    }

    func loadTimeline() async {
        // Show loading only on first load
        if !hasLoadedOnce {
            isLoading = true
        }

        do {
            // Fetch 24 hours of data to support time scrubbing through the day
            let feed = try await apiClient.getTimeline(hours: 24)

            let now = Date()
            var newFlowingItems: [FlowingItem] = []
            var newPiledItems: [FlowingItem] = []

            for item in feed.items {
                // Skip items that are already completed, skipped, or postponed
                // These should not appear in the flowing timeline or pile
                switch item.status {
                case .completed, .skipped, .postponed:
                    continue
                case .pending, .active, .upcoming:
                    break
                }

                let flowingItem = createFlowingItem(from: item)

                if let scheduledTime = flowingItem.scheduledTime {
                    if scheduledTime <= now {
                        var piledItem = flowingItem
                        piledItem.arrivedAt = scheduledTime
                        newPiledItems.append(piledItem)
                    } else {
                        newFlowingItems.append(flowingItem)
                    }
                } else {
                    newPiledItems.append(flowingItem)
                }
            }

            // Animate changes
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                flowingItems = newFlowingItems
                piledUpItems = newPiledItems
                error = nil
                showErrorBanner = false
            }

            hasLoadedOnce = true
            updateItemPositions()
            checkForReminders()

            timelineLogger.info("Timeline loaded: \(newFlowingItems.count) flowing, \(newPiledItems.count) piled")

        } catch let apiError as APIError {
            timelineLogger.error("Failed to load timeline: \(apiError.errorDescription ?? "unknown")")
            error = apiError
            // Only show full error view if we haven't loaded anything yet
            if !hasLoadedOnce {
                // Error will be shown in the view
            } else {
                // Show banner for background refresh failures
                showErrorBanner = true
            }
        } catch {
            timelineLogger.error("Failed to load timeline: \(error.localizedDescription)")
            self.error = .unknown(error)
        }

        isLoading = false
    }

    /// Retry loading after an error
    func retry() {
        Task {
            await loadTimeline()
        }
    }

    /// Dismiss error banner
    func dismissError() {
        withAnimation {
            showErrorBanner = false
        }
    }

    /// Show a toast message
    func showToastMessage(_ message: String, style: MaToast.Style = .info) {
        toastMessage = message
        toastStyle = style
        showToast = true
    }

    private func createFlowingItem(from item: TimelineFeedItem) -> FlowingItem {
        let color = colorForItem(item)
        let scheduledTime = parseTime(item.scheduledTime)
        let endTime = parseTime(item.windowEnd)

        // Calculate duration from scheduled time to end time, or use default
        var estimatedMinutes = 15
        if let start = scheduledTime, let end = endTime {
            let duration = end.timeIntervalSince(start)
            if duration > 0 {
                estimatedMinutes = Int(duration / 60)
            }
        }

        return FlowingItem(
            id: item.id,
            code: item.code,  // Use code for API calls
            title: item.title,
            scheduledTime: scheduledTime,
            endTime: endTime,
            color: color,
            streak: item.currentStreak,
            estimatedMinutes: estimatedMinutes,
            timelineItem: item
        )
    }

    private func colorForItem(_ item: TimelineFeedItem) -> Color {
        let category = item.category?.lowercased() ?? ""
        let title = item.title.lowercased()

        // Special color for sleep
        if category == "sleep" || title.contains("sleep") || title.contains("bed") {
            return Color(hex: "#5C6BC0") // Indigo for sleep
        }

        switch category {
        case "habit":
            return MaColors.primaryLight
        case "routine":
            return MaColors.secondary
        case "event":
            return MaColors.xp
        case "reminder":
            return MaColors.postpone
        case "health":
            return MaColors.complete
        case "work":
            return MaColors.streak
        default:
            return MaColors.primaryLight
        }
    }

    private func parseTime(_ timeString: String?) -> Date? {
        guard let timeString = timeString else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        guard let time = formatter.date(from: timeString) else { return nil }

        let calendar = Calendar.current
        let now = Date()

        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: 0,
            of: now
        )
    }

    private func updateItemPositions() {
        let now = Date()
        // Use displayTime for positioning when scrubbing, otherwise use actual time
        let referenceTime = isScrubbing ? displayTime : now
        let oneHour: TimeInterval = 3600
        let nowY = screenHeight * nowLineY

        // Item height for stacking (approximate bubble height + spacing)
        let itemHeight: CGFloat = 50

        // Group items by their scheduled time to handle stacking
        var timeSlots: [TimeInterval: [Int]] = [:]

        for i in flowingItems.indices {
            guard let scheduledTime = flowingItems[i].scheduledTime else { continue }
            let timeKey = scheduledTime.timeIntervalSince1970
            if timeSlots[timeKey] == nil {
                timeSlots[timeKey] = []
            }
            timeSlots[timeKey]?.append(i)
        }

        // Track indices to remove (items that should move to pile)
        var indicesToRemove: [Int] = []

        // When scrubbing, don't move items to pile - just reposition them
        for i in flowingItems.indices {
            guard let scheduledTime = flowingItems[i].scheduledTime else { continue }

            let timeUntil = scheduledTime.timeIntervalSince(referenceTime)

            // Only move to pile when NOT scrubbing and time has passed
            if !isScrubbing && timeUntil <= 0 {
                indicesToRemove.append(i)
                continue
            }

            // Calculate position based on time until scheduled
            // Items more than 1 hour away are at the top, items at scheduled time are at nowY
            let progress: Double
            if timeUntil <= 0 {
                // Past the scheduled time - show below the now line
                progress = 1.0 + min(abs(timeUntil) / oneHour, 0.3) // Slightly past nowY
            } else {
                progress = 1 - min(timeUntil / oneHour, 1.0)
            }

            var targetY = topY + (nowY - topY) * CGFloat(progress)

            // Stack items with the same scheduled time vertically
            let timeKey = scheduledTime.timeIntervalSince1970
            if let sameTimeIndices = timeSlots[timeKey], sameTimeIndices.count > 1 {
                if let stackIndex = sameTimeIndices.firstIndex(of: i) {
                    // Offset each item in the stack
                    targetY += CGFloat(stackIndex) * itemHeight
                }
            }

            // Smooth easing for position updates
            let currentY = flowingItems[i].currentY
            let newY = currentY + (targetY - currentY) * 0.1

            flowingItems[i].currentY = newY

            // Calculate endY for duration events
            if flowingItems[i].isDurationEvent, let endTime = flowingItems[i].endTime {
                let endTimeUntil = endTime.timeIntervalSince(referenceTime)
                let endProgress: Double
                if endTimeUntil <= 0 {
                    endProgress = 1.0 + min(abs(endTimeUntil) / oneHour, 0.3)
                } else {
                    endProgress = 1 - min(endTimeUntil / oneHour, 1.0)
                }
                let targetEndY = topY + (nowY - topY) * CGFloat(endProgress)
                let currentEndY = flowingItems[i].endY
                flowingItems[i].endY = currentEndY + (targetEndY - currentEndY) * 0.1
            }

            // Smooth opacity - show items within 2 hours of display time
            let hoursAway = abs(timeUntil) / 3600
            let targetOpacity = hoursAway <= 2 ? min((2 - hoursAway) / 1.5, 1.0) : 0.0
            flowingItems[i].opacity = flowingItems[i].opacity + (targetOpacity - flowingItems[i].opacity) * 0.1

            // Smooth scale
            let targetScale = 0.85 + (0.15 * CGFloat(max(0, min(progress, 1.0))))
            flowingItems[i].scale = flowingItems[i].scale + (targetScale - flowingItems[i].scale) * 0.1

            // Gentle floating offset with sine wave - reduced for stacked items and duration events
            let floatOffset = sin(now.timeIntervalSince1970 * 0.5 + Double(i)) * 3
            let sameTimeCount = timeSlots[timeKey]?.count ?? 1
            // Reduce horizontal offset when stacked so items stay aligned
            // Duration events don't float - they stay fixed
            let isDuration = flowingItems[i].isDurationEvent
            let horizontalReduction = isDuration ? 0.0 : (sameTimeCount > 1 ? 0.3 : 1.0)
            let offsetDirection: CGFloat = i.isMultiple(of: 2) ? 1 : -1
            let baseOffset = offsetDirection * (70 - 40 * CGFloat(max(0, min(progress, 1.0)))) * CGFloat(horizontalReduction)
            flowingItems[i].horizontalOffset = isDuration ? 0 : baseOffset + CGFloat(floatOffset)
        }

        // Remove items that should move to pile (in reverse order to preserve indices)
        for i in indicesToRemove.reversed() {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                var piledItem = flowingItems[i]
                piledItem.arrivedAt = now
                piledUpItems.append(piledItem)
            }
            flowingItems.remove(at: i)
        }
    }

    /// Track items that have already triggered a reminder to avoid spam
    private var remindedItemIds: Set<String> = []

    private func checkForReminders() {
        for item in piledUpItems where item.needsReminder {
            // Only trigger reminder once per item
            if !remindedItemIds.contains(item.id) {
                scheduleReminder(for: item)
                remindedItemIds.insert(item.id)
            }
        }

        // Clean up reminded IDs for items no longer in pile
        let currentPileIds = Set(piledUpItems.map { $0.id })
        remindedItemIds = remindedItemIds.intersection(currentPileIds)
    }

    private func scheduleReminder(for item: FlowingItem) {
        timelineLogger.debug("Reminder needed for: \(item.title)")
        // TODO: Implement actual notification scheduling
    }

    func selectItem(_ item: FlowingItem) {
        withAnimation(.spring(response: 0.3)) {
            selectedItem = item
        }
    }

    func completeItem(_ item: FlowingItem) {
        Task {
            do {
                let response = try await apiClient.completeItem(code: item.code)
                timelineLogger.info("Completed \(item.title): XP=\(response.xpGranted), streak=\(response.newStreak)")

                // Add to recently completed items
                let completedItem = CompletedItem(
                    id: item.id,
                    title: item.title,
                    completedAt: Date(),
                    xpGranted: response.xpGranted,
                    newStreak: response.newStreak,
                    color: item.color,
                    icon: item.timelineItem.icon
                )

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    recentlyCompletedItems.insert(completedItem, at: 0)
                }

                // Show success toast
                if response.totalXP > 0 {
                    showToastMessage("+\(response.totalXP) XP", style: .success)
                }

                await loadTimeline()
            } catch let apiError as APIError {
                // Handle specific cases like "already completed"
                if case .serverError(400, let message) = apiError, message.contains("already completed") {
                    timelineLogger.info("\(item.title) was already completed today")
                    showToastMessage("Already completed today", style: .info)
                    await loadTimeline() // Refresh to show updated state
                } else {
                    timelineLogger.error("Failed to complete \(item.title): \(apiError.errorDescription ?? "unknown")")
                    showToastMessage(apiError.errorDescription ?? "Failed to complete", style: .error)
                }
            } catch {
                timelineLogger.error("Failed to complete \(item.title): \(error.localizedDescription)")
                showToastMessage("Failed to complete task", style: .error)
            }
        }
    }

    func postponeItem(_ item: FlowingItem) {
        Task {
            do {
                let response = try await apiClient.postponeItem(code: item.code, target: .afternoon)
                timelineLogger.info("Postponed \(item.title): \(response.message)")
                showToastMessage("Postponed to later", style: .info)
                await loadTimeline()
            } catch let apiError as APIError {
                timelineLogger.error("Failed to postpone \(item.title): \(apiError.errorDescription ?? "unknown")")
                showToastMessage(apiError.errorDescription ?? "Failed to postpone", style: .error)
            } catch {
                timelineLogger.error("Failed to postpone \(item.title): \(error.localizedDescription)")
                showToastMessage("Failed to postpone task", style: .error)
            }
        }
    }

    func skipItem(_ item: FlowingItem) {
        Task {
            do {
                try await apiClient.skipItem(code: item.code)
                timelineLogger.info("Skipped \(item.title)")
                showToastMessage("Task skipped", style: .info)
                await loadTimeline()
            } catch let apiError as APIError {
                timelineLogger.error("Failed to skip \(item.title): \(apiError.errorDescription ?? "unknown")")
                showToastMessage(apiError.errorDescription ?? "Failed to skip", style: .error)
            } catch {
                timelineLogger.error("Failed to skip \(item.title): \(error.localizedDescription)")
                showToastMessage("Failed to skip task", style: .error)
            }
        }
    }

    func bundleQuickTasks() {
        let quickTasks = piledUpItems.filter { $0.estimatedMinutes <= 5 }

        Task {
            var totalXP = 0
            var completedCount = 0

            for task in quickTasks {
                do {
                    let response = try await apiClient.completeItem(code: task.code)
                    totalXP += response.totalXP
                    completedCount += 1
                    timelineLogger.info("Completed \(task.title): XP=\(response.totalXP)")
                } catch {
                    timelineLogger.error("Failed to complete \(task.title): \(error.localizedDescription)")
                }
            }

            if completedCount > 0 {
                showToastMessage("\(completedCount) tasks done! +\(totalXP) XP", style: .success)
            }

            await loadTimeline()
        }
    }
}

// MARK: - TimelineItem Extension for itemType

extension TimelineItem {
    var itemType: TimelineItemType {
        // Determine type based on available data
        if recurrence != nil {
            return .habit
        } else if timeAnchor != nil {
            return .routine
        } else {
            return .event
        }
    }

    var currentStreak: Int {
        // This would come from the API, returning 0 as default
        return 0
    }

    var estimatedMinutes: Int? {
        return windowMinutes > 0 ? windowMinutes : 15
    }

    var scheduledTime: String? {
        return defaultTime
    }
}

enum TimelineItemType {
    case habit
    case routine
    case event
    case reminder
}

// MARK: - Preview

#Preview {
    MaFlowingTimelineView()
}
