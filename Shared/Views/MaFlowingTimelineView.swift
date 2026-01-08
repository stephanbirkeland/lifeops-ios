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

// MARK: - Flowing Timeline View

struct MaFlowingTimelineView: View {
    @StateObject private var viewModel = FlowingTimelineViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var showCompletionCelebration = false
    @State private var completedItemPosition: CGPoint = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Weather and time-aware background
                MaWeatherTimeBackground(
                    displayTime: viewModel.currentTime,
                    weather: .clear  // TODO: Integrate with weather service
                )
                .ignoresSafeArea()

                // Central timeline with gradient glow
                MaEnhancedTimelinePath(screenHeight: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Flowing events with enhanced animations
                ForEach(viewModel.flowingItems) { item in
                    MaEnhancedFlowingBubble(
                        item: item,
                        screenHeight: geometry.size.height,
                        onTap: { viewModel.selectItem(item) }
                    )
                    .position(
                        x: geometry.size.width / 2 + item.horizontalOffset,
                        y: item.currentY
                    )
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

                // Current time indicator with breathing animation
                MaEnhancedTimeIndicator()
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.7)

                // Piled up tasks at bottom with friendly presentation
                VStack(spacing: 0) {
                    Spacer()

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
                }
                .padding(.bottom, MaSpacing.lg)

                // Top header with flowing time display
                VStack {
                    MaEnhancedFlowingHeader(currentTime: viewModel.currentTime)
                    Spacer()
                }

                // Completion celebration overlay
                if showCompletionCelebration {
                    MaFlowingCompletionCelebration(position: completedItemPosition)
                        .allowsHitTesting(false)
                }
            }
        }
        .sheet(item: $viewModel.selectedItem) { item in
            MaFlowingItemDetailSheet(
                item: item,
                onComplete: { viewModel.completeItem(item) },
                onPostpone: { viewModel.postponeItem(item) },
                onSkip: { viewModel.skipItem(item) }
            )
        }
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

// MARK: - Enhanced Time Indicator

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

// MARK: - Enhanced Flowing Header

struct MaEnhancedFlowingHeader: View {
    let currentTime: Date
    @Environment(\.colorScheme) var colorScheme
    @State private var colonOpacity: Double = 1

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MaSpacing.xxs) {
                // Time with breathing colon
                HStack(spacing: 0) {
                    Text(hourString)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(MaColors.textPrimary)
                        .monospacedDigit()

                    Text(":")
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(MaColors.textPrimary.opacity(colonOpacity))

                    Text(minuteString)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(MaColors.textPrimary)
                        .monospacedDigit()
                }

                Text(dateString)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textSecondary)
            }

            Spacer()

            // Zen leaf with gentle sway
            MaBreathingLeaf()
        }
        .padding(.horizontal, MaSpacing.lg)
        .padding(.top, MaSpacing.lg)
        .background(
            LinearGradient(
                colors: [
                    MaColors.background,
                    MaColors.background.opacity(0.95),
                    MaColors.background.opacity(0)
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
        .onAppear {
            // Occasional shimmer
            withAnimation(.linear(duration: 3).delay(Double.random(in: 0...5))) {
                shimmer = 1.5
            }
        }
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

                                Image(systemName: item.timelineItem.icon ?? "circle")
                                    .font(.system(size: 36))
                                    .foregroundStyle(item.color)
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
    let title: String
    let scheduledTime: Date?
    let color: Color
    let streak: Int
    let estimatedMinutes: Int
    let timelineItem: TimelineFeedItem

    // Animation properties
    var currentY: CGFloat = 0
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var horizontalOffset: CGFloat = 0
    var arrivedAt: Date?

    // Enhanced animation state
    var entranceProgress: CGFloat = 0

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

// MARK: - Flowing Timeline ViewModel

@MainActor
class FlowingTimelineViewModel: ObservableObject {
    @Published var flowingItems: [FlowingItem] = []
    @Published var piledUpItems: [FlowingItem] = []
    @Published var currentTime = Date()
    @Published var selectedItem: FlowingItem?

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var flowTimer: Timer?
    private let apiClient = APIClient.shared

    // Screen dimensions
    private var screenHeight: CGFloat = UIScreen.main.bounds.height
    private let nowLineY: CGFloat = 0.7 // 70% down the screen
    private let topY: CGFloat = 100

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
    }

    @objc private func updateFrame(_ displayLink: CADisplayLink) {
        let currentFrameTime = displayLink.timestamp

        // Update time display once per second
        if currentFrameTime - lastUpdateTime >= 1.0 {
            currentTime = Date()
            lastUpdateTime = currentFrameTime
        }

        // Smooth position updates every frame
        updateItemPositions()
    }

    func loadTimeline() async {
        do {
            let feed = try await apiClient.getTimeline(hours: 2)

            let now = Date()
            var newFlowingItems: [FlowingItem] = []
            var newPiledItems: [FlowingItem] = []

            for item in feed.items {
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
            }

            updateItemPositions()
            checkForReminders()

        } catch {
            print("Failed to load timeline: \(error)")
        }
    }

    private func createFlowingItem(from item: TimelineFeedItem) -> FlowingItem {
        let color = colorForItem(item)
        let scheduledTime = parseTime(item.scheduledTime)

        return FlowingItem(
            id: item.id,
            title: item.title,
            scheduledTime: scheduledTime,
            color: color,
            streak: item.currentStreak,
            estimatedMinutes: 15, // Default estimate
            timelineItem: item
        )
    }

    private func colorForItem(_ item: TimelineFeedItem) -> Color {
        switch item.category?.lowercased() {
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
        let oneHour: TimeInterval = 3600
        let nowY = screenHeight * nowLineY

        for i in flowingItems.indices {
            guard let scheduledTime = flowingItems[i].scheduledTime else { continue }

            let timeUntil = scheduledTime.timeIntervalSince(now)

            if timeUntil <= 0 {
                // Move to pile with animation
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    var piledItem = flowingItems[i]
                    piledItem.arrivedAt = now
                    piledUpItems.append(piledItem)
                }

                flowingItems.remove(at: i)
                continue
            }

            // Smooth interpolation for position
            let progress = 1 - min(timeUntil / oneHour, 1.0)
            let targetY = topY + (nowY - topY) * CGFloat(progress)

            // Smooth easing for position updates
            let currentY = flowingItems[i].currentY
            let newY = currentY + (targetY - currentY) * 0.1

            flowingItems[i].currentY = newY

            // Smooth opacity fade-in
            let targetOpacity = min(progress * 2.5, 1.0)
            flowingItems[i].opacity = flowingItems[i].opacity + (targetOpacity - flowingItems[i].opacity) * 0.1

            // Smooth scale
            let targetScale = 0.85 + (0.15 * CGFloat(progress))
            flowingItems[i].scale = flowingItems[i].scale + (targetScale - flowingItems[i].scale) * 0.1

            // Gentle floating offset with sine wave
            let floatOffset = sin(now.timeIntervalSince1970 * 0.5 + Double(i)) * 3
            let offsetDirection: CGFloat = i.isMultiple(of: 2) ? 1 : -1
            let baseOffset = offsetDirection * (70 - 40 * CGFloat(progress))
            flowingItems[i].horizontalOffset = baseOffset + CGFloat(floatOffset)
        }
    }

    private func checkForReminders() {
        for item in piledUpItems where item.needsReminder {
            scheduleReminder(for: item)
        }
    }

    private func scheduleReminder(for item: FlowingItem) {
        print("Reminder needed for: \(item.title)")
    }

    func selectItem(_ item: FlowingItem) {
        withAnimation(.spring(response: 0.3)) {
            selectedItem = item
        }
    }

    func completeItem(_ item: FlowingItem) {
        Task {
            do {
                _ = try await apiClient.completeItem(code: item.id)
                await loadTimeline()
            } catch {
                print("Failed to complete: \(error)")
            }
        }
    }

    func postponeItem(_ item: FlowingItem) {
        Task {
            do {
                _ = try await apiClient.postponeItem(code: item.id, target: .afternoon)
                await loadTimeline()
            } catch {
                print("Failed to postpone: \(error)")
            }
        }
    }

    func skipItem(_ item: FlowingItem) {
        Task {
            do {
                try await apiClient.skipItem(code: item.id)
                await loadTimeline()
            } catch {
                print("Failed to skip: \(error)")
            }
        }
    }

    func bundleQuickTasks() {
        let quickTasks = piledUpItems.filter { $0.estimatedMinutes <= 5 }

        Task {
            for task in quickTasks {
                try? await apiClient.completeItem(code: task.id)
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
