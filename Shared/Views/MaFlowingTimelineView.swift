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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                MaColors.background
                    .ignoresSafeArea()

                // Central timeline
                MaTimelinePath()
                    .stroke(
                        MaColors.border.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 8])
                    )
                    .frame(width: 2)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Current time indicator
                MaCurrentTimeIndicator()
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.7)

                // Flowing events
                ForEach(viewModel.flowingItems) { item in
                    MaFlowingEventBubble(
                        item: item,
                        screenHeight: geometry.size.height,
                        onTap: { viewModel.selectItem(item) }
                    )
                    .position(
                        x: geometry.size.width / 2 + item.horizontalOffset,
                        y: item.currentY
                    )
                }

                // Piled up tasks at bottom
                VStack(spacing: 0) {
                    Spacer()

                    if !viewModel.piledUpItems.isEmpty {
                        MaTaskPileView(
                            items: viewModel.piledUpItems,
                            onComplete: viewModel.completeItem,
                            onPostpone: viewModel.postponeItem,
                            onBundle: viewModel.bundleQuickTasks
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, MaSpacing.lg)

                // Top header with current time
                VStack {
                    MaFlowingHeader(currentTime: viewModel.currentTime)
                    Spacer()
                }
            }
        }
        .sheet(item: $viewModel.selectedItem) { item in
            ItemDetailSheet(item: item.timelineItem)
        }
        .onAppear {
            viewModel.startFlowing()
        }
        .onDisappear {
            viewModel.stopFlowing()
        }
    }
}

// MARK: - Timeline Path

struct MaTimelinePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        return path
    }
}

// MARK: - Current Time Indicator

struct MaCurrentTimeIndicator: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(MaColors.primarySoft.opacity(0.3))
                .frame(width: 24, height: 24)
                .scaleEffect(pulse ? 1.3 : 1.0)

            // Inner dot
            Circle()
                .fill(MaColors.primaryLight)
                .frame(width: 12, height: 12)

            // "Now" label
            Text("now")
                .font(MaTypography.caption)
                .foregroundStyle(MaColors.textSecondary)
                .offset(x: 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Flowing Header

struct MaFlowingHeader: View {
    let currentTime: Date
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MaSpacing.xxs) {
                Text(timeString)
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .foregroundStyle(MaColors.textPrimary)
                    .monospacedDigit()

                Text(dateString)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textSecondary)
            }

            Spacer()

            // Leaf icon
            Image(systemName: "leaf")
                .font(.title2)
                .foregroundStyle(MaColors.primaryLight.opacity(0.5))
        }
        .padding(.horizontal, MaSpacing.lg)
        .padding(.top, MaSpacing.lg)
        .background(
            LinearGradient(
                colors: [
                    MaColors.background,
                    MaColors.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .ignoresSafeArea()
        )
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentTime)
    }
}

// MARK: - Flowing Event Bubble

struct MaFlowingEventBubble: View {
    let item: FlowingItem
    let screenHeight: CGFloat
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MaSpacing.sm) {
                // Color indicator
                Circle()
                    .fill(item.color)
                    .frame(width: 10, height: 10)

                // Title
                Text(item.title)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textPrimary)
                    .lineLimit(1)

                // Time
                if let time = item.scheduledTime {
                    Text(formatTime(time))
                        .font(MaTypography.caption)
                        .foregroundStyle(MaColors.textTertiary)
                }

                // Streak badge
                if item.streak > 0 {
                    MaStreakBadge(count: item.streak)
                }
            }
            .padding(.horizontal, MaSpacing.md)
            .padding(.vertical, MaSpacing.sm)
            .background(
                Capsule()
                    .fill(MaColors.backgroundSecondary)
                    .shadow(
                        color: colorScheme == .dark ? .clear : item.color.opacity(0.15),
                        radius: 8,
                        y: 2
                    )
            )
            .overlay(
                Capsule()
                    .stroke(item.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(item.opacity)
        .scaleEffect(item.scale)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Task Pile View

struct MaTaskPileView: View {
    let items: [FlowingItem]
    let onComplete: (FlowingItem) -> Void
    let onPostpone: (FlowingItem) -> Void
    let onBundle: () -> Void

    @State private var expandedPile = false
    @Environment(\.colorScheme) var colorScheme

    private var quickTasks: [FlowingItem] {
        items.filter { $0.estimatedMinutes <= 5 }
    }

    private var regularTasks: [FlowingItem] {
        items.filter { $0.estimatedMinutes > 5 }
    }

    var body: some View {
        VStack(spacing: MaSpacing.sm) {
            // Quick tasks bundle
            if quickTasks.count >= 2 {
                MaQuickTaskBundle(
                    tasks: quickTasks,
                    onBundle: onBundle
                )
            }

            // Main pile
            if expandedPile {
                // Expanded view - show all tasks
                VStack(spacing: MaSpacing.xs) {
                    ForEach(items) { item in
                        MaPiledTaskRow(
                            item: item,
                            onComplete: { onComplete(item) },
                            onPostpone: { onPostpone(item) }
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Collapsed view - stacked cards
                MaStackedPile(
                    items: items,
                    onTap: { expandedPile = true }
                )
            }

            // Collapse button when expanded
            if expandedPile && items.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        expandedPile = false
                    }
                } label: {
                    Text("Collapse")
                        .font(MaTypography.caption)
                        .foregroundStyle(MaColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, MaSpacing.lg)
        .animation(.spring(response: 0.4), value: expandedPile)
    }
}

// MARK: - Stacked Pile (Collapsed View)

struct MaStackedPile: View {
    let items: [FlowingItem]
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Stacked background cards
                ForEach(Array(items.prefix(3).enumerated().reversed()), id: \.element.id) { index, item in
                    RoundedRectangle(cornerRadius: MaRadius.lg)
                        .fill(MaColors.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: MaRadius.lg)
                                .stroke(item.color.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(
                            color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                            radius: 4,
                            y: 2
                        )
                        .offset(y: CGFloat(index) * -6)
                        .scaleEffect(1 - CGFloat(index) * 0.03)
                }

                // Front card content
                if let frontItem = items.first {
                    HStack {
                        Circle()
                            .fill(frontItem.color)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(frontItem.title)
                                .font(MaTypography.bodyMedium)
                                .foregroundStyle(MaColors.textPrimary)

                            if items.count > 1 {
                                Text("+\(items.count - 1) more waiting")
                                    .font(MaTypography.caption)
                                    .foregroundStyle(MaColors.textTertiary)
                            }
                        }

                        Spacer()

                        // Gentle pulse for attention
                        Circle()
                            .fill(MaColors.postpone.opacity(0.8))
                            .frame(width: 8, height: 8)
                    }
                    .padding(MaSpacing.md)
                }
            }
            .frame(height: 60)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Piled Task Row

struct MaPiledTaskRow: View {
    let item: FlowingItem
    let onComplete: () -> Void
    let onPostpone: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: MaSpacing.sm) {
            // Color dot
            Circle()
                .fill(item.color)
                .frame(width: 10, height: 10)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textPrimary)

                Text(item.waitingTimeText)
                    .font(MaTypography.caption)
                    .foregroundStyle(MaColors.textTertiary)
            }

            Spacer()

            // Quick actions
            HStack(spacing: MaSpacing.xs) {
                Button(action: onPostpone) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body)
                        .foregroundStyle(MaColors.postpone)
                        .padding(MaSpacing.xs)
                        .background(Circle().fill(MaColors.postponeSoft))
                }

                Button(action: onComplete) {
                    Image(systemName: "checkmark")
                        .font(.body)
                        .foregroundStyle(MaColors.complete)
                        .padding(MaSpacing.xs)
                        .background(Circle().fill(MaColors.completeSoft))
                }
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
                .stroke(item.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Quick Task Bundle

struct MaQuickTaskBundle: View {
    let tasks: [FlowingItem]
    let onBundle: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onBundle) {
            HStack(spacing: MaSpacing.sm) {
                // Bundled dots
                HStack(spacing: -4) {
                    ForEach(tasks.prefix(4)) { task in
                        Circle()
                            .fill(task.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(MaColors.backgroundSecondary, lineWidth: 2)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(tasks.count) quick tasks")
                        .font(MaTypography.labelMedium)
                        .foregroundStyle(MaColors.textPrimary)

                    Text("Tap to bundle & complete")
                        .font(MaTypography.caption)
                        .foregroundStyle(MaColors.textTertiary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.body)
                    .foregroundStyle(MaColors.xp)
            }
            .padding(MaSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MaRadius.lg)
                    .fill(MaColors.xpSoft.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaRadius.lg)
                    .stroke(MaColors.xp.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flowing Item Model

struct FlowingItem: Identifiable {
    let id: String
    let title: String
    let scheduledTime: Date?
    let color: Color
    let streak: Int
    let estimatedMinutes: Int
    let timelineItem: TimelineItem

    // Animation properties
    var currentY: CGFloat = 0
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var horizontalOffset: CGFloat = 0
    var arrivedAt: Date?

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

    private var timer: Timer?
    private var flowTimer: Timer?
    private let apiClient = APIClient.shared

    // Screen height for positioning
    private var screenHeight: CGFloat = UIScreen.main.bounds.height
    private let nowLineY: CGFloat = 0.7 // 70% down the screen

    func startFlowing() {
        // Update current time every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
                self?.updateItemPositions()
            }
        }

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
        timer?.invalidate()
        timer = nil
        flowTimer?.invalidate()
        flowTimer = nil
    }

    func loadTimeline() async {
        do {
            let feed = try await apiClient.getTimeline(hours: 2)

            // Convert to flowing items
            let now = Date()
            var newFlowingItems: [FlowingItem] = []
            var newPiledItems: [FlowingItem] = []

            for item in feed.items {
                let flowingItem = createFlowingItem(from: item)

                if let scheduledTime = flowingItem.scheduledTime {
                    if scheduledTime <= now {
                        // Past due - goes to pile
                        var piledItem = flowingItem
                        piledItem.arrivedAt = scheduledTime
                        newPiledItems.append(piledItem)
                    } else {
                        // Future - flows down
                        newFlowingItems.append(flowingItem)
                    }
                } else {
                    // No time - goes to pile
                    newPiledItems.append(flowingItem)
                }
            }

            flowingItems = newFlowingItems
            piledUpItems = newPiledItems

            updateItemPositions()
            checkForReminders()

        } catch {
            print("Failed to load timeline: \(error)")
        }
    }

    private func createFlowingItem(from item: TimelineItem) -> FlowingItem {
        let color = colorForItem(item)
        let scheduledTime = parseTime(item.scheduledTime)

        return FlowingItem(
            id: item.id,
            title: item.title,
            scheduledTime: scheduledTime,
            color: color,
            streak: item.currentStreak,
            estimatedMinutes: item.estimatedMinutes ?? 15,
            timelineItem: item
        )
    }

    private func colorForItem(_ item: TimelineItem) -> Color {
        // Color based on category or type
        switch item.itemType {
        case .habit:
            return MaColors.primaryLight
        case .routine:
            return MaColors.secondary
        case .event:
            return MaColors.xp
        case .reminder:
            return MaColors.postpone
        default:
            return MaColors.primaryLight
        }
    }

    private func parseTime(_ timeString: String?) -> Date? {
        guard let timeString = timeString else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        guard let time = formatter.date(from: timeString) else { return nil }

        // Combine with today's date
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
        let topY: CGFloat = 100 // Top of visible area

        for i in flowingItems.indices {
            guard let scheduledTime = flowingItems[i].scheduledTime else { continue }

            let timeUntil = scheduledTime.timeIntervalSince(now)

            if timeUntil <= 0 {
                // Should move to pile
                var piledItem = flowingItems[i]
                piledItem.arrivedAt = now
                piledUpItems.append(piledItem)
                flowingItems.remove(at: i)
                continue
            }

            // Position based on time until event
            // 1 hour away = top of screen
            // 0 minutes away = now line (70% down)
            let progress = 1 - min(timeUntil / oneHour, 1.0)
            let targetY = topY + (nowY - topY) * CGFloat(progress)

            flowingItems[i].currentY = targetY

            // Fade in as it approaches
            flowingItems[i].opacity = min(progress * 2, 1.0)

            // Scale up slightly as it gets closer
            flowingItems[i].scale = 0.8 + (0.2 * CGFloat(progress))

            // Alternate horizontal offset for visual interest
            let offsetDirection: CGFloat = i.isMultiple(of: 2) ? 1 : -1
            flowingItems[i].horizontalOffset = offsetDirection * (80 - 30 * CGFloat(progress))
        }
    }

    private func checkForReminders() {
        for item in piledUpItems where item.needsReminder {
            // Schedule local notification
            scheduleReminder(for: item)
        }
    }

    private func scheduleReminder(for item: FlowingItem) {
        // Local notification would be scheduled here
        // For now, this is a placeholder
        print("Reminder needed for: \(item.title)")
    }

    func selectItem(_ item: FlowingItem) {
        selectedItem = item
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
                _ = try await apiClient.postponeItem(code: item.id, target: .later)
                await loadTimeline()
            } catch {
                print("Failed to postpone: \(error)")
            }
        }
    }

    func bundleQuickTasks() {
        // Complete all quick tasks at once
        let quickTasks = piledUpItems.filter { $0.estimatedMinutes <= 5 }

        Task {
            for task in quickTasks {
                try? await apiClient.completeItem(code: task.id)
            }
            await loadTimeline()
        }
    }
}

// MARK: - Preview

#Preview {
    MaFlowingTimelineView()
}
