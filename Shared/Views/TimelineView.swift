// TimelineView.swift
// Main rolling timeline view

import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var showingFullDay = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Overdue section (if any)
                    if !viewModel.overdueItems.isEmpty {
                        TimelineSection(
                            title: "Overdue",
                            items: viewModel.overdueItems,
                            style: .overdue
                        ) { item in
                            viewModel.selectedItem = item
                        }
                    }

                    // Active/Current section
                    if !viewModel.activeItems.isEmpty {
                        TimelineSection(
                            title: "Now",
                            items: viewModel.activeItems,
                            style: .active
                        ) { item in
                            viewModel.selectedItem = item
                        }
                    }

                    // Upcoming section
                    if !viewModel.upcomingItems.isEmpty {
                        TimelineSection(
                            title: "Upcoming",
                            items: viewModel.upcomingItems,
                            style: .upcoming
                        ) { item in
                            viewModel.selectedItem = item
                        }
                    }

                    // Completed section
                    if !viewModel.completedItems.isEmpty {
                        TimelineSection(
                            title: "Completed",
                            items: viewModel.completedItems,
                            style: .completed
                        ) { item in
                            viewModel.selectedItem = item
                        }
                    }

                    // Empty state
                    if viewModel.isEmpty {
                        EmptyTimelineView()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFullDay.toggle()
                    } label: {
                        Image(systemName: showingFullDay ? "clock" : "calendar")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
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

// MARK: - Timeline Section

struct TimelineSection: View {
    let title: String
    let items: [TimelineFeedItem]
    let style: SectionStyle
    let onItemTap: (TimelineFeedItem) -> Void

    enum SectionStyle {
        case overdue, active, upcoming, completed

        var headerColor: Color {
            switch self {
            case .overdue: return .red
            case .active: return .blue
            case .upcoming: return .secondary
            case .completed: return .green
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(style.headerColor)

                Spacer()

                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Items
            ForEach(items) { item in
                TimelineItemRow(item: item, style: style)
                    .onTapGesture { onItemTap(item) }
            }
        }
    }
}

// MARK: - Timeline Item Row

struct TimelineItemRow: View {
    let item: TimelineFeedItem
    let style: TimelineSection.SectionStyle

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            // Icon
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(style == .completed)

                HStack(spacing: 8) {
                    if let time = item.scheduledTime {
                        Label(formatTimeString(time), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if item.currentStreak > 0 {
                        Label("\(item.currentStreak)", systemImage: "flame")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if item.xpReward > 0 {
                        Label("+\(item.xpReward)", systemImage: "star")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private var statusColor: Color {
        switch style {
        case .overdue: return .red
        case .active: return .blue
        case .upcoming: return .gray
        case .completed: return .green
        }
    }

    private var iconColor: Color {
        return .primary
    }

    private func formatTimeString(_ timeStr: String) -> String {
        // Parse "HH:mm:ss" format and display as "h:mm a"
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

// MARK: - Empty State

struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("All caught up!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No items in your timeline right now.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    TimelineView()
}
