// WatchTimelineView.swift
// Simplified timeline view for Apple Watch - Ma Design System
//
// Ma (間) - Calm, focused experience on the wrist

import SwiftUI

struct WatchTimelineView: View {
    @StateObject private var viewModel = WatchTimelineViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    WatchLoadingView()
                } else if viewModel.items.isEmpty {
                    WatchEmptyView()
                } else {
                    WatchTimelineList(items: viewModel.items, viewModel: viewModel)
                }
            }
            .navigationTitle("Timeline")
        }
        .task {
            await viewModel.loadTimeline()
        }
    }
}

// MARK: - Watch Loading View

struct WatchLoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(WatchMaColors.primary)
            Text("Loading...")
                .font(.caption)
                .foregroundStyle(WatchMaColors.textSecondary)
        }
    }
}

// MARK: - Watch Empty View

struct WatchEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(WatchMaColors.completeSoft)
                    .frame(width: 48, height: 48)

                Image(systemName: "checkmark")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(WatchMaColors.complete)
            }

            Text("All done!")
                .font(.headline)
                .foregroundStyle(WatchMaColors.textPrimary)

            Text("Take a breath")
                .font(.caption2)
                .foregroundStyle(WatchMaColors.textSecondary)
        }
    }
}

// MARK: - Watch Timeline List

struct WatchTimelineList: View {
    let items: [TimelineFeedItem]
    @ObservedObject var viewModel: WatchTimelineViewModel

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    WatchItemRow(item: item)
                }
                .listRowBackground(WatchMaColors.backgroundSecondary)
            }
        }
        .navigationDestination(for: TimelineFeedItem.self) { item in
            WatchItemDetail(item: item, viewModel: viewModel)
        }
    }
}

// MARK: - Watch Item Row

struct WatchItemRow: View {
    let item: TimelineFeedItem

    var body: some View {
        HStack(spacing: 8) {
            // Status dot with color
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(WatchMaColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let time = item.scheduledTime {
                        Text(formatTimeString(time))
                            .font(.caption2)
                            .foregroundStyle(WatchMaColors.textSecondary)
                    }

                    if item.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(WatchMaColors.streak)
                            Text("\(item.currentStreak)")
                                .foregroundStyle(WatchMaColors.streak)
                        }
                        .font(.caption2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if item.isOverdue { return WatchMaColors.overdue }
        switch item.status {
        case .active: return WatchMaColors.primary
        case .completed: return WatchMaColors.complete
        default: return WatchMaColors.textTertiary
        }
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

// MARK: - Watch Item Detail

struct WatchItemDetail: View {
    let item: TimelineFeedItem
    @ObservedObject var viewModel: WatchTimelineViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Icon with status color
                if let icon = item.icon {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.2))
                            .frame(width: 56, height: 56)

                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(iconColor)
                    }
                }

                // Title
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(WatchMaColors.textPrimary)
                    .multilineTextAlignment(.center)

                // Streak badge
                if item.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(item.currentStreak) day streak")
                    }
                    .font(.caption)
                    .foregroundStyle(WatchMaColors.streak)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(WatchMaColors.streak.opacity(0.2))
                    )
                }

                // XP reward
                if item.xpReward > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("+\(item.xpReward) XP")
                    }
                    .font(.caption)
                    .foregroundStyle(WatchMaColors.xp)
                }

                Divider()

                // Actions
                if item.status != .completed {
                    // Complete Button
                    Button {
                        completeItem()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WatchMaColors.complete)

                    // Quick Postpone
                    Button {
                        postponeItem(.afterWork)
                    } label: {
                        Label("Later", systemImage: "clock")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    // Skip
                    Button(role: .destructive) {
                        skipItem()
                    } label: {
                        Label("Skip", systemImage: "forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Completed!")
                    }
                    .foregroundStyle(WatchMaColors.complete)
                    .font(.headline)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var iconColor: Color {
        if item.isOverdue { return WatchMaColors.overdue }
        switch item.status {
        case .active: return WatchMaColors.primary
        case .completed: return WatchMaColors.complete
        default: return WatchMaColors.textSecondary
        }
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

// MARK: - Watch Ma Colors (Simplified for Watch)

struct WatchMaColors {
    // Primary
    static let primary = Color(hex: "7EB8DA")

    // Semantic
    static let complete = Color(hex: "8FBC8F")
    static let completeSoft = Color(hex: "2D4A2D")
    static let overdue = Color(hex: "E88B8B")
    static let postpone = Color(hex: "E8B86D")

    // Gamification
    static let streak = Color(hex: "F5A855")
    static let xp = Color(hex: "A68BC8")

    // Backgrounds
    static let background = Color(hex: "1A1918")
    static let backgroundSecondary = Color(hex: "252423")

    // Text
    static let textPrimary = Color(hex: "F5F3F0")
    static let textSecondary = Color(hex: "A8A5A0")
    static let textTertiary = Color(hex: "6B6560")
}

// MARK: - Color Extension (for Watch)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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
