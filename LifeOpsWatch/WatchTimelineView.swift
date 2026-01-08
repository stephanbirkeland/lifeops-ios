// WatchTimelineView.swift
// Simplified timeline view for Apple Watch

import SwiftUI

struct WatchTimelineView: View {
    @StateObject private var viewModel = WatchTimelineViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("All done!")
                            .font(.headline)
                    }
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            NavigationLink(value: item) {
                                WatchItemRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
            .navigationDestination(for: TimelineFeedItem.self) { item in
                WatchItemDetail(item: item, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadTimeline()
        }
    }
}

// MARK: - Watch Item Row

struct WatchItemRow: View {
    let item: TimelineFeedItem

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let time = item.scheduledTime {
                        Text(formatTime(time))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if item.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                            Text("\(item.currentStreak)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        if item.isOverdue { return .red }
        switch item.status {
        case .active: return .blue
        case .completed: return .green
        default: return .gray
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Watch Item Detail

struct WatchItemDetail: View {
    let item: TimelineFeedItem
    @ObservedObject var viewModel: WatchTimelineViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Icon
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundStyle(iconColor)
                }

                // Title
                Text(item.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                // Streak
                if item.currentStreak > 0 {
                    HStack {
                        Image(systemName: "flame.fill")
                        Text("\(item.currentStreak) day streak")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                Divider()

                // Actions
                if item.status != .completed {
                    // Complete Button
                    Button {
                        completeItem()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    // Quick Postpone
                    Button {
                        postponeItem(.afterWork)
                    } label: {
                        Label("Later", systemImage: "clock")
                    }
                    .buttonStyle(.bordered)

                    // Skip
                    Button(role: .destructive) {
                        skipItem()
                    } label: {
                        Label("Skip", systemImage: "forward")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Label("Completed!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
    }

    private var iconColor: Color {
        if let colorName = item.color {
            return Color(colorName)
        }
        return .blue
    }

    private func completeItem() {
        Task {
            await viewModel.completeItem(item)
            dismiss()
        }
    }

    private func postponeItem(_ target: PostponeTarget) {
        Task {
            await viewModel.postponeItem(item, target: target)
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

// MARK: - Watch ViewModel

@MainActor
class WatchTimelineViewModel: ObservableObject {
    @Published var items: [TimelineFeedItem] = []
    @Published var isLoading = false

    private let api = APIClient.shared

    var activeAndOverdueItems: [TimelineFeedItem] {
        items.filter { $0.status == .active || $0.isOverdue }
    }

    func loadTimeline() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let feed = try await api.getTimeline(hours: 4)
            // Show overdue + active items (most relevant for watch)
            items = feed.overdue + feed.items.filter { $0.status == .active }
        } catch {
            print("Error loading timeline: \(error)")
        }
    }

    func completeItem(_ item: TimelineFeedItem) async {
        do {
            _ = try await api.completeItem(code: item.code)
            await loadTimeline()
        } catch {
            print("Error completing item: \(error)")
        }
    }

    func postponeItem(_ item: TimelineFeedItem, target: PostponeTarget) async {
        do {
            _ = try await api.postponeItem(code: item.code, target: target)
            await loadTimeline()
        } catch {
            print("Error postponing item: \(error)")
        }
    }

    func skipItem(_ item: TimelineFeedItem) async {
        do {
            try await api.skipItem(code: item.code)
            await loadTimeline()
        } catch {
            print("Error skipping item: \(error)")
        }
    }
}

#Preview {
    WatchTimelineView()
}
