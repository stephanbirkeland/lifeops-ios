// ItemDetailSheet.swift
// Detail view with actions for a timeline item - Ma Design System
//
// Ma (間) - Thoughtful, calming detail experience

import SwiftUI

struct ItemDetailSheet: View {
    let item: TimelineFeedItem
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showPostponeOptions = false
    @State private var showSkipConfirmation = false
    @State private var notes = ""
    @State private var quality: Int = 0
    @State private var showCompletionCelebration = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MaColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MaSpacing.xl) {
                        // Header
                        MaItemHeader(item: item)

                        // Stats
                        MaItemStats(item: item)

                        // Divider with breathing room
                        MaDivider()

                        // Quick Actions
                        MaQuickActions(
                            onComplete: { completeItem() },
                            onPostpone: { showPostponeOptions = true },
                            onSkip: { showSkipConfirmation = true },
                            isCompleted: item.status == .completed
                        )

                        // Notes (for completion)
                        if item.status != .completed {
                            MaNotesSection(notes: $notes)
                        }

                        // Quality Rating
                        if item.status != .completed {
                            MaQualityRating(quality: $quality)
                        }

                        // Bottom breathing room
                        Spacer()
                            .frame(height: MaSpacing.xl)
                    }
                    .padding(MaSpacing.lg)
                }

                // Celebration overlay
                if showCompletionCelebration {
                    MaCompletionCelebration()
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MaColors.primaryLight)
                }
            }
            .sheet(isPresented: $showPostponeOptions) {
                MaPostponeSheet(item: item, viewModel: viewModel) {
                    dismiss()
                }
            }
            .alert("Skip this item?", isPresented: $showSkipConfirmation) {
                Button("Skip", role: .destructive) { skipItem() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This won't affect your streak, but you won't earn XP.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(MaColors.background)
    }

    private func completeItem() {
        // Show celebration briefly
        withAnimation(MaAnimation.spring) {
            showCompletionCelebration = true
        }

        Task {
            await viewModel.completeItem(
                item,
                notes: notes.isEmpty ? nil : notes,
                quality: quality > 0 ? quality : nil
            )

            // Delay dismiss to show celebration
            try? await Task.sleep(nanoseconds: 800_000_000)

            await MainActor.run {
                dismiss()
            }
        }
    }

    private func skipItem() {
        Task {
            await viewModel.skipItem(item)
            dismiss()
        }
    }
}

// MARK: - Ma Item Header

struct MaItemHeader: View {
    let item: TimelineFeedItem
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: MaSpacing.md) {
            // Icon with soft background
            ZStack {
                Circle()
                    .fill(iconBackgroundGradient)
                    .frame(width: 88, height: 88)
                    .shadow(
                        color: iconColor.opacity(colorScheme == .dark ? 0.3 : 0.2),
                        radius: 12,
                        y: 4
                    )

                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 38))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 38))
                        .foregroundStyle(.white)
                }
            }

            // Description
            if let description = item.description {
                Text(description)
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MaSpacing.md)
            }

            // Time info
            if let time = item.scheduledTime {
                HStack(spacing: MaSpacing.xs) {
                    Image(systemName: "clock")
                        .foregroundStyle(MaColors.textTertiary)

                    Text(formatTimeString(time))
                        .foregroundStyle(MaColors.textPrimary)

                    if let windowEnd = item.windowEnd {
                        Text("-")
                            .foregroundStyle(MaColors.textTertiary)
                        Text(formatTimeString(windowEnd))
                            .foregroundStyle(MaColors.textSecondary)
                    }
                }
                .font(MaTypography.bodySmall)
            }

            // Status badge
            MaStatusBadge(status: item.status, isOverdue: item.isOverdue)
        }
    }

    private var iconColor: Color {
        MaColors.statusColor(for: item.status, isOverdue: item.isOverdue)
    }

    private var iconBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [iconColor, iconColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

// MARK: - Ma Status Badge

struct MaStatusBadge: View {
    let status: ItemStatus
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: MaSpacing.xxxs) {
            Image(systemName: icon)
            Text(text)
        }
        .font(MaTypography.labelSmall)
        .foregroundStyle(.white)
        .padding(.horizontal, MaSpacing.sm)
        .padding(.vertical, MaSpacing.xxs)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }

    private var icon: String {
        if isOverdue { return "exclamationmark.circle" }
        switch status {
        case .pending: return "circle"
        case .active: return "play.circle"
        case .upcoming: return "clock"
        case .completed: return "checkmark.circle"
        case .skipped: return "forward.circle"
        case .postponed: return "clock.arrow.circlepath"
        }
    }

    private var text: String {
        if isOverdue { return "Overdue" }
        switch status {
        case .pending: return "Pending"
        case .active: return "Active"
        case .upcoming: return "Upcoming"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        case .postponed: return "Postponed"
        }
    }

    private var backgroundColor: Color {
        MaColors.statusColor(for: status, isOverdue: isOverdue)
    }
}

// MARK: - Ma Item Stats

struct MaItemStats: View {
    let item: TimelineFeedItem
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: MaSpacing.md) {
            MaStatCard(
                icon: "flame.fill",
                value: "\(item.currentStreak)",
                label: "Streak",
                color: MaColors.streak,
                softColor: MaColors.secondarySoft
            )

            MaStatCard(
                icon: "trophy.fill",
                value: "\(item.bestStreak)",
                label: "Best",
                color: MaColors.trophy,
                softColor: MaColors.secondarySoft
            )

            MaStatCard(
                icon: "sparkles",
                value: "+\(item.xpReward)",
                label: "XP",
                color: MaColors.xp,
                softColor: MaColors.xpSoft
            )
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

struct MaStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let softColor: Color

    var body: some View {
        VStack(spacing: MaSpacing.xs) {
            ZStack {
                Circle()
                    .fill(softColor)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(MaTypography.statSmall)
                .foregroundStyle(MaColors.textPrimary)

            Text(label)
                .font(MaTypography.caption)
                .foregroundStyle(MaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ma Divider

struct MaDivider: View {
    var body: some View {
        Rectangle()
            .fill(MaColors.divider)
            .frame(height: 1)
            .padding(.horizontal, MaSpacing.lg)
    }
}

// MARK: - Ma Quick Actions

struct MaQuickActions: View {
    let onComplete: () -> Void
    let onPostpone: () -> Void
    let onSkip: () -> Void
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: MaSpacing.sm) {
            if !isCompleted {
                // Complete button (primary - prominent)
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(MaTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MaSpacing.md)
                }
                .buttonStyle(MaPrimaryButtonStyle(color: MaColors.complete))

                HStack(spacing: MaSpacing.sm) {
                    // Postpone button
                    Button(action: onPostpone) {
                        Label("Postpone", systemImage: "clock.arrow.circlepath")
                            .font(MaTypography.labelMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, MaSpacing.sm)
                    }
                    .buttonStyle(MaSecondaryButtonStyle())

                    // Skip button
                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward")
                            .font(MaTypography.labelMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, MaSpacing.sm)
                    }
                    .buttonStyle(MaSecondaryButtonStyle())
                }
            } else {
                // Already completed
                HStack(spacing: MaSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Completed!")
                }
                .font(MaTypography.titleMedium)
                .foregroundStyle(MaColors.complete)
                .padding(.vertical, MaSpacing.md)
            }
        }
    }
}

// MARK: - Ma Notes Section

struct MaNotesSection: View {
    @Binding var notes: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MaSpacing.xs) {
            Text("Notes")
                .font(MaTypography.labelMedium)
                .foregroundStyle(MaColors.textSecondary)

            TextField("Add notes about this task...", text: $notes, axis: .vertical)
                .font(MaTypography.bodyMedium)
                .lineLimit(3...6)
                .padding(MaSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: MaRadius.sm)
                        .fill(MaColors.backgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MaRadius.sm)
                        .stroke(isFocused ? MaColors.primaryLight : .clear, lineWidth: 1)
                )
                .focused($isFocused)
        }
    }
}

// MARK: - Ma Quality Rating

struct MaQualityRating: View {
    @Binding var quality: Int
    @State private var hoveredRating: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: MaSpacing.xs) {
            Text("How did it go?")
                .font(MaTypography.labelMedium)
                .foregroundStyle(MaColors.textSecondary)

            HStack(spacing: MaSpacing.sm) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        withAnimation(MaAnimation.spring) {
                            quality = quality == rating ? 0 : rating
                        }
                    } label: {
                        Image(systemName: rating <= quality ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(
                                rating <= quality
                                    ? MaColors.trophy
                                    : MaColors.textTertiary
                            )
                            .scaleEffect(rating <= quality ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if quality > 0 {
                    Text(qualityLabel)
                        .font(MaTypography.labelSmall)
                        .foregroundStyle(MaColors.textSecondary)
                        .transition(.opacity)
                }
            }
            .padding(MaSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MaRadius.md)
                    .fill(MaColors.backgroundTertiary)
            )
        }
    }

    private var qualityLabel: String {
        switch quality {
        case 1: return "Struggled"
        case 2: return "Okay"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Perfect!"
        default: return ""
        }
    }
}

// MARK: - Ma Postpone Sheet

struct MaPostponeSheet: View {
    let item: TimelineFeedItem
    @ObservedObject var viewModel: TimelineViewModel
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MaColors.background
                    .ignoresSafeArea()

                List {
                    Section {
                        ForEach(PostponeTarget.allCases.filter { $0 != .custom }, id: \.self) { target in
                            Button {
                                postponeTo(target)
                            } label: {
                                HStack(spacing: MaSpacing.sm) {
                                    ZStack {
                                        Circle()
                                            .fill(MaColors.postponeSoft)
                                            .frame(width: 36, height: 36)

                                        Image(systemName: target.icon)
                                            .font(.body)
                                            .foregroundStyle(MaColors.postpone)
                                    }

                                    Text(target.displayName)
                                        .font(MaTypography.bodyMedium)
                                        .foregroundStyle(MaColors.textPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(MaColors.textTertiary)
                                }
                                .padding(.vertical, MaSpacing.xxs)
                            }
                        }
                    } header: {
                        Text("Quick Options")
                            .font(MaTypography.labelSmall)
                            .foregroundStyle(MaColors.textSecondary)
                    }
                    .listRowBackground(MaColors.backgroundSecondary)

                    Section {
                        Button {
                            // TODO: Show date/time picker
                            postponeTo(.tomorrow)
                        } label: {
                            HStack(spacing: MaSpacing.sm) {
                                ZStack {
                                    Circle()
                                        .fill(MaColors.primarySoft)
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "calendar.badge.clock")
                                        .font(.body)
                                        .foregroundStyle(MaColors.primaryLight)
                                }

                                Text("Pick date & time...")
                                    .font(MaTypography.bodyMedium)
                                    .foregroundStyle(MaColors.textPrimary)

                                Spacer()
                            }
                            .padding(.vertical, MaSpacing.xxs)
                        }
                    } header: {
                        Text("Custom")
                            .font(MaTypography.labelSmall)
                            .foregroundStyle(MaColors.textSecondary)
                    }
                    .listRowBackground(MaColors.backgroundSecondary)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Postpone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(MaColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(MaColors.background)
    }

    private func postponeTo(_ target: PostponeTarget) {
        Task {
            await viewModel.postponeItem(item, target: target)
            dismiss()
            onDismiss()
        }
    }
}

// MARK: - Ma Completion Celebration

struct MaCompletionCelebration: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: MaSpacing.md) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(MaGradients.success)
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(scale)

                Text("Well done!")
                    .font(MaTypography.titleLarge)
                    .foregroundStyle(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(MaAnimation.reward) {
                scale = 1.0
            }
            withAnimation(MaAnimation.smooth.delay(0.2)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ItemDetailSheet(
        item: TimelineFeedItem(
            id: "1",
            code: "morning_workout",
            name: "Morning Workout",
            description: "30 minutes of exercise to start the day",
            icon: "figure.run",
            category: "health",
            scheduledTime: "08:00:00",
            windowEnd: "09:00:00",
            status: .active,
            currentStreak: 5,
            bestStreak: 12,
            completedAt: nil,
            statRewards: ["STR": 30, "VIT": 20]
        ),
        viewModel: TimelineViewModel()
    )
}
