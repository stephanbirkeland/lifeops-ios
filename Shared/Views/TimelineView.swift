// TimelineView.swift
// Main rolling timeline view - Ma Design System
//
// Ma (間) - The space to breathe. A calming timeline experience.

import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var showingFullDay = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background gradient
                MaGradients.sunrise
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Daily progress header
                        if let feed = viewModel.feed {
                            DailyProgressHeader(
                                completed: feed.completedToday,
                                total: feed.totalToday,
                                rate: feed.completionRate
                            )
                            .padding(.horizontal, MaSpacing.md)
                            .padding(.top, MaSpacing.sm)
                            .padding(.bottom, MaSpacing.lg)
                        }

                        // Overdue section (if any)
                        if !viewModel.overdueItems.isEmpty {
                            MaTimelineSection(
                                title: "Overdue",
                                subtitle: "Needs attention",
                                items: viewModel.overdueItems,
                                style: .overdue
                            ) { item in
                                viewModel.selectedItem = item
                            }
                        }

                        // Active/Current section
                        if !viewModel.activeItems.isEmpty {
                            MaTimelineSection(
                                title: "Now",
                                subtitle: "Focus on these",
                                items: viewModel.activeItems,
                                style: .active
                            ) { item in
                                viewModel.selectedItem = item
                            }
                        }

                        // Upcoming section
                        if !viewModel.upcomingItems.isEmpty {
                            MaTimelineSection(
                                title: "Coming Up",
                                subtitle: nil,
                                items: viewModel.upcomingItems,
                                style: .upcoming
                            ) { item in
                                viewModel.selectedItem = item
                            }
                        }

                        // Completed section
                        if !viewModel.completedItems.isEmpty {
                            MaTimelineSection(
                                title: "Done",
                                subtitle: nil,
                                items: viewModel.completedItems,
                                style: .completed
                            ) { item in
                                viewModel.selectedItem = item
                            }
                        }

                        // Empty state
                        if viewModel.isEmpty {
                            MaEmptyTimelineView()
                        }

                        // Bottom breathing room
                        Spacer()
                            .frame(height: MaSpacing.xxxl)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(MaAnimation.smooth) {
                            showingFullDay.toggle()
                        }
                    } label: {
                        Image(systemName: showingFullDay ? "clock" : "calendar")
                            .foregroundStyle(MaColors.primaryLight)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(MaColors.primaryLight)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $viewModel.selectedItem) { item in
                ItemDetailSheet(item: item, viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.loadTimeline(expand: showingFullDay)
            }
            .onChange(of: showingFullDay) { _, newValue in
                Task { await viewModel.loadTimeline(expand: newValue) }
            }
        }
    }
}

// MARK: - Daily Progress Header

struct DailyProgressHeader: View {
    let completed: Int
    let total: Int
    let rate: Double
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: MaSpacing.md) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(MaColors.backgroundTertiary, lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(
                        MaGradients.success,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(rate * 100))")
                        .font(MaTypography.statSmall)
                        .foregroundStyle(MaColors.textPrimary)
                    Text("%")
                        .font(MaTypography.captionSmall)
                        .foregroundStyle(MaColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: MaSpacing.xxxs) {
                Text("Today's Progress")
                    .font(MaTypography.labelMedium)
                    .foregroundStyle(MaColors.textSecondary)

                Text("\(completed) of \(total) completed")
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textPrimary)
            }

            Spacer()

            // Encouragement based on progress
            if rate >= 1.0 {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(MaColors.trophy)
            } else if rate >= 0.5 {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(MaColors.xp)
            }
        }
        .padding(MaSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MaRadius.lg)
                .fill(MaColors.backgroundSecondary)
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                    radius: 8,
                    y: 2
                )
        )
    }
}

// MARK: - Ma Timeline Section

struct MaTimelineSection: View {
    let title: String
    let subtitle: String?
    let items: [TimelineFeedItem]
    let style: SectionStyle
    let onItemTap: (TimelineFeedItem) -> Void

    enum SectionStyle {
        case overdue, active, upcoming, completed

        var accentColor: Color {
            switch self {
            case .overdue: return MaColors.overdue
            case .active: return MaColors.primaryLight
            case .upcoming: return MaColors.textTertiary
            case .completed: return MaColors.complete
            }
        }

        var icon: String {
            switch self {
            case .overdue: return "exclamationmark.circle"
            case .active: return "play.circle"
            case .upcoming: return "clock"
            case .completed: return "checkmark.circle"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MaSpacing.sm) {
            // Section header
            HStack(alignment: .firstTextBaseline, spacing: MaSpacing.xs) {
                Image(systemName: style.icon)
                    .font(.subheadline)
                    .foregroundStyle(style.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MaTypography.titleSmall)
                        .foregroundStyle(style.accentColor)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(MaTypography.caption)
                            .foregroundStyle(MaColors.textTertiary)
                    }
                }

                Spacer()

                Text("\(items.count)")
                    .font(MaTypography.labelSmall)
                    .foregroundStyle(MaColors.textTertiary)
                    .padding(.horizontal, MaSpacing.xs)
                    .padding(.vertical, MaSpacing.xxxs)
                    .background(
                        Capsule()
                            .fill(MaColors.backgroundTertiary)
                    )
            }
            .padding(.horizontal, MaSpacing.md)
            .padding(.top, MaSpacing.lg)

            // Items
            VStack(spacing: MaSpacing.xs) {
                ForEach(items) { item in
                    MaTimelineItemRow(item: item, style: style)
                        .onTapGesture { onItemTap(item) }
                }
            }
            .padding(.horizontal, MaSpacing.md)
        }
    }
}

// MARK: - Ma Timeline Item Row

struct MaTimelineItemRow: View {
    let item: TimelineFeedItem
    let style: MaTimelineSection.SectionStyle
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: MaSpacing.sm) {
            // Status indicator with subtle animation for active items
            MaStatusDot(
                status: item.status,
                isOverdue: item.isOverdue,
                size: 10,
                animated: style == .active || style == .overdue
            )

            // Icon in soft background
            if let icon = item.icon {
                ZStack {
                    Circle()
                        .fill(MaColors.statusSoftColor(for: item.status, isOverdue: item.isOverdue))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(MaColors.statusColor(for: item.status, isOverdue: item.isOverdue))
                }
            } else {
                ZStack {
                    Circle()
                        .fill(MaColors.backgroundTertiary)
                        .frame(width: 36, height: 36)

                    Image(systemName: "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(MaColors.textTertiary)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: MaSpacing.xxxs) {
                Text(item.title)
                    .font(MaTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        style == .completed
                            ? MaColors.textSecondary
                            : MaColors.textPrimary
                    )
                    .strikethrough(style == .completed, color: MaColors.textTertiary)

                HStack(spacing: MaSpacing.sm) {
                    if let time = item.scheduledTime {
                        HStack(spacing: MaSpacing.xxxs) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatTimeString(time))
                        }
                        .font(MaTypography.caption)
                        .foregroundStyle(MaColors.textSecondary)
                    }

                    // Streak badge
                    if item.currentStreak > 0 {
                        MaStreakBadge(streak: item.currentStreak, isCompact: true)
                    }

                    // XP badge
                    if item.xpReward > 0 && style != .completed {
                        MaXPBadge(xp: item.xpReward, isCompact: true)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(MaColors.textTertiary)
        }
        .padding(MaSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MaRadius.md)
                .fill(MaColors.backgroundSecondary)
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.03),
                    radius: 4,
                    y: 1
                )
        )
        .contentShape(Rectangle())
    }

    private func formatTimeString(_ timeStr: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm:ss"
        guard let date = inputFormatter.date(from: timeStr) else {
            return timeStr
        }
        let outputFormatter = DateFormatter()
        outputFormatter.timeStyle = .short
        return outputFormatter.string(from: date)
    }
}

// MARK: - Ma Empty State

struct MaEmptyTimelineView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: MaSpacing.lg) {
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(MaColors.completeSoft)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(MaColors.complete)
            }

            VStack(spacing: MaSpacing.xs) {
                Text("All caught up")
                    .font(MaTypography.titleLarge)
                    .foregroundStyle(MaColors.textPrimary)

                Text("Take a moment to breathe.")
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textSecondary)

                Text("This is your Ma.")
                    .font(MaTypography.caption)
                    .foregroundStyle(MaColors.textTertiary)
                    .italic()
            }
            .multilineTextAlignment(.center)
        }
        .padding(MaSpacing.xxxl)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    TimelineView()
}
