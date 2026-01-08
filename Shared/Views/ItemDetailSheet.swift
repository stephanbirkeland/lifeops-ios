// ItemDetailSheet.swift
// Detail view with actions for a timeline item

import SwiftUI

struct ItemDetailSheet: View {
    let item: TimelineFeedItem
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showPostponeOptions = false
    @State private var showSkipConfirmation = false
    @State private var notes = ""
    @State private var quality: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    ItemHeader(item: item)

                    // Stats
                    ItemStats(item: item)

                    Divider()

                    // Quick Actions
                    QuickActions(
                        onComplete: { completeItem() },
                        onPostpone: { showPostponeOptions = true },
                        onSkip: { showSkipConfirmation = true },
                        isCompleted: item.status == .completed
                    )

                    // Notes (for completion)
                    if item.status != .completed {
                        NotesSection(notes: $notes)
                    }

                    // Quality Rating
                    if item.status != .completed {
                        QualityRating(quality: $quality)
                    }
                }
                .padding()
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPostponeOptions) {
                PostponeSheet(item: item, viewModel: viewModel) {
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
    }

    private func completeItem() {
        Task {
            await viewModel.completeItem(
                item,
                notes: notes.isEmpty ? nil : notes,
                quality: quality > 0 ? quality : nil
            )
            dismiss()
        }
    }

    private func skipItem() {
        Task {
            await viewModel.skipItem(item)
            dismiss()
        }
    }
}

// MARK: - Item Header

struct ItemHeader: View {
    let item: TimelineFeedItem

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 80, height: 80)

                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
            }

            // Description
            if let description = item.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Time info
            if let time = item.scheduledTime {
                HStack {
                    Image(systemName: "clock")
                    Text(formatTimeString(time))

                    if let windowEnd = item.windowEnd {
                        Text("(until \(formatTimeString(windowEnd)))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }

            // Status badge
            StatusBadge(status: item.status, isOverdue: item.isOverdue)
        }
    }

    private var iconBackgroundColor: Color {
        return .blue
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

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ItemStatus
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor, in: Capsule())
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
        if isOverdue { return .red }
        switch status {
        case .pending: return .gray
        case .active: return .blue
        case .upcoming: return .secondary
        case .completed: return .green
        case .skipped: return .orange
        case .postponed: return .purple
        }
    }
}

// MARK: - Item Stats

struct ItemStats: View {
    let item: TimelineFeedItem

    var body: some View {
        HStack(spacing: 24) {
            StatItem(
                icon: "flame",
                value: "\(item.currentStreak)",
                label: "Streak",
                color: .orange
            )

            StatItem(
                icon: "trophy",
                value: "\(item.bestStreak)",
                label: "Best",
                color: .yellow
            )

            StatItem(
                icon: "star.fill",
                value: "+\(item.xpReward)",
                label: "XP",
                color: .purple
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Actions

struct QuickActions: View {
    let onComplete: () -> Void
    let onPostpone: () -> Void
    let onSkip: () -> Void
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 12) {
            if !isCompleted {
                // Complete button (primary)
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 12) {
                    // Postpone button
                    Button(action: onPostpone) {
                        Label("Postpone", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Skip button
                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                // Already completed
                Label("Completed!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Notes Section

struct NotesSection: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Add notes...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Quality Rating

struct QualityRating: View {
    @Binding var quality: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How did it go? (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        quality = quality == rating ? 0 : rating
                    } label: {
                        Image(systemName: rating <= quality ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(rating <= quality ? .yellow : .gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Postpone Sheet

struct PostponeSheet: View {
    let item: TimelineFeedItem
    @ObservedObject var viewModel: TimelineViewModel
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Options") {
                    ForEach(PostponeTarget.allCases.filter { $0 != .custom }, id: \.self) { target in
                        Button {
                            postponeTo(target)
                        } label: {
                            Label(target.displayName, systemImage: target.icon)
                        }
                    }
                }

                Section("Custom") {
                    Button {
                        // TODO: Show date/time picker
                        postponeTo(.tomorrow)
                    } label: {
                        Label("Pick date & time...", systemImage: "calendar.badge.clock")
                    }
                }
            }
            .navigationTitle("Postpone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func postponeTo(_ target: PostponeTarget) {
        Task {
            await viewModel.postponeItem(item, target: target)
            dismiss()
            onDismiss()
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
