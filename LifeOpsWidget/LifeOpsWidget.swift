// LifeOpsWidget.swift
// Home screen widget for LifeOps timeline

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct MaTimelineEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
    let configuration: ConfigurationAppIntent
}

struct WidgetItem: Identifiable {
    let id: String
    let title: String
    let icon: String?
    let time: Date?
    let isOverdue: Bool
    let streak: Int
}

// MARK: - Timeline Provider

struct TimelineProvider: AppIntentTimelineProvider {
    typealias Entry = MaTimelineEntry
    typealias Intent = ConfigurationAppIntent

    func placeholder(in context: Context) -> MaTimelineEntry {
        MaTimelineEntry(
            date: Date(),
            items: [
                WidgetItem(id: "1", title: "Morning Workout", icon: "figure.run", time: Date(), isOverdue: false, streak: 5),
                WidgetItem(id: "2", title: "Take Vitamins", icon: "pill", time: Date(), isOverdue: false, streak: 12),
            ],
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> MaTimelineEntry {
        // Return sample data for widget gallery
        MaTimelineEntry(
            date: Date(),
            items: [
                WidgetItem(id: "1", title: "Morning Workout", icon: "figure.run", time: Date(), isOverdue: false, streak: 5),
                WidgetItem(id: "2", title: "Take Vitamins", icon: "pill", time: Date(), isOverdue: false, streak: 12),
                WidgetItem(id: "3", title: "Review Tasks", icon: "checklist", time: Date().addingTimeInterval(3600), isOverdue: false, streak: 3),
            ],
            configuration: configuration
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<MaTimelineEntry> {
        // Fetch real data from API
        let items = await fetchTimelineItems()

        let entry = MaTimelineEntry(
            date: Date(),
            items: items,
            configuration: configuration
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchTimelineItems() async -> [WidgetItem] {
        // Try to fetch from API
        do {
            let feed = try await WidgetAPIClient.shared.getTimeline()

            // Get all items from feed (overdue computed, plus active/upcoming)
            let allItems = feed.items.filter { $0.status == .active || $0.status == .upcoming || $0.isOverdue }
            return allItems.prefix(5).map { item in
                WidgetItem(
                    id: item.id,
                    title: item.title,
                    icon: item.icon,
                    time: parseTimeString(item.scheduledTime),
                    isOverdue: item.isOverdue,
                    streak: item.currentStreak
                )
            }
        } catch {
            // Return empty on error
            return []
        }
    }

    private func parseTimeString(_ timeStr: String?) -> Date? {
        guard let timeStr = timeStr else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeStr) else { return nil }

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
}

// MARK: - Configuration Intent

import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Timeline Widget"
    static var description = IntentDescription("Shows your upcoming timeline items.")

    @Parameter(title: "Show Streaks", default: true)
    var showStreaks: Bool
}

// MARK: - Widget Views

struct LifeOpsWidgetEntryView: View {
    var entry: MaTimelineEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.blue)
                Text("Timeline")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            // Next item or empty state
            if let item = entry.items.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if item.isOverdue {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                        }
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                    }

                    if let time = item.time {
                        Text(formatTime(time))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if item.streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(item.streak)")
                        }
                        .font(.caption2)
                    }
                }
            } else {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("All done!")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()

            // Count
            if entry.items.count > 1 {
                Text("+\(entry.items.count - 1) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.blue)
                Text("Timeline")
                    .font(.headline)

                Spacer()

                Text(entry.items.isEmpty ? "All done!" : "\(entry.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("Nothing pending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Show up to 3 items
                ForEach(entry.items.prefix(3)) { item in
                    WidgetItemRow(item: item, showStreak: entry.configuration.showStreaks)
                }

                if entry.items.count > 3 {
                    Text("+\(entry.items.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.blue)
                Text("Timeline")
                    .font(.headline)

                Spacer()

                Text(Date(), style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if entry.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("All caught up!")
                        .font(.title3)
                    Text("No pending items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Show up to 6 items
                ForEach(entry.items.prefix(6)) { item in
                    WidgetItemRow(item: item, showStreak: entry.configuration.showStreaks)
                    if item.id != entry.items.prefix(6).last?.id {
                        Divider()
                    }
                }

                Spacer()

                if entry.items.count > 6 {
                    Text("+\(entry.items.count - 6) more items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Item Row

struct WidgetItemRow: View {
    let item: WidgetItem
    let showStreak: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(item.isOverdue ? .red : .blue)
                .frame(width: 8, height: 8)

            // Icon
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }

            // Title
            Text(item.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // Time
            if let time = item.time {
                Text(formatTime(time))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Streak
            if showStreak && item.streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                    Text("\(item.streak)")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Lock Screen Widgets

struct CircularWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            if entry.items.isEmpty {
                Image(systemName: "checkmark")
                    .font(.title2)
            } else {
                VStack(spacing: 0) {
                    Text("\(entry.items.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("todo")
                        .font(.caption2)
                }
            }
        }
    }
}

struct RectangularWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        if let item = entry.items.first {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let time = item.time {
                        Text(time, style: .time)
                            .font(.caption)
                    }
                }

                Spacer()

                if item.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                        Text("\(item.streak)")
                    }
                    .foregroundStyle(.orange)
                }
            }
        } else {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("All done!")
            }
        }
    }
}

struct InlineWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        if let item = entry.items.first {
            Text("\(entry.items.count) items • \(item.title)")
        } else {
            Text("All done!")
        }
    }
}

// MARK: - Widget Bundle

@main
struct LifeOpsWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeOpsTimelineWidget()
    }
}

struct LifeOpsTimelineWidget: Widget {
    let kind: String = "LifeOpsTimeline"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: TimelineProvider()
        ) { entry in
            LifeOpsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Timeline")
        .description("See your upcoming tasks at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    LifeOpsTimelineWidget()
} timeline: {
    MaTimelineEntry(
        date: Date(),
        items: [
            WidgetItem(id: "1", title: "Morning Workout", icon: "figure.run", time: Date(), isOverdue: false, streak: 5),
            WidgetItem(id: "2", title: "Take Vitamins", icon: "pill", time: Date(), isOverdue: false, streak: 12),
        ],
        configuration: ConfigurationAppIntent()
    )
}

#Preview("Medium", as: .systemMedium) {
    LifeOpsTimelineWidget()
} timeline: {
    MaTimelineEntry(
        date: Date(),
        items: [
            WidgetItem(id: "1", title: "Morning Workout", icon: "figure.run", time: Date(), isOverdue: true, streak: 5),
            WidgetItem(id: "2", title: "Take Vitamins", icon: "pill", time: Date(), isOverdue: false, streak: 12),
            WidgetItem(id: "3", title: "Review Tasks", icon: "checklist", time: Date().addingTimeInterval(3600), isOverdue: false, streak: 3),
        ],
        configuration: ConfigurationAppIntent()
    )
}

#Preview("Large", as: .systemLarge) {
    LifeOpsTimelineWidget()
} timeline: {
    MaTimelineEntry(
        date: Date(),
        items: [
            WidgetItem(id: "1", title: "Morning Workout", icon: "figure.run", time: Date(), isOverdue: true, streak: 5),
            WidgetItem(id: "2", title: "Take Vitamins", icon: "pill", time: Date(), isOverdue: false, streak: 12),
            WidgetItem(id: "3", title: "Review Tasks", icon: "checklist", time: Date().addingTimeInterval(3600), isOverdue: false, streak: 3),
            WidgetItem(id: "4", title: "Lunch Break", icon: "fork.knife", time: Date().addingTimeInterval(7200), isOverdue: false, streak: 0),
            WidgetItem(id: "5", title: "Team Standup", icon: "person.3", time: Date().addingTimeInterval(10800), isOverdue: false, streak: 20),
        ],
        configuration: ConfigurationAppIntent()
    )
}

#Preview("Empty", as: .systemMedium) {
    LifeOpsTimelineWidget()
} timeline: {
    MaTimelineEntry(
        date: Date(),
        items: [],
        configuration: ConfigurationAppIntent()
    )
}
