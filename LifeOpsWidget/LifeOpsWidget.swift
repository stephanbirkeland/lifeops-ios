// LifeOpsWidget.swift
// Home screen widget for Ma timeline - Ma Design System
//
// Ma (間) - A glance of calm amidst the day

import WidgetKit
import SwiftUI
import AppIntents

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
        let items = await fetchTimelineItems()

        let entry = MaTimelineEntry(
            date: Date(),
            items: items,
            configuration: configuration
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchTimelineItems() async -> [WidgetItem] {
        do {
            let feed = try await WidgetAPIClient.shared.getTimeline()
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
            return []
        }
    }

    private func parseTimeString(_ timeStr: String?) -> Date? {
        guard let timeStr = timeStr else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeStr) else { return nil }

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

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Ma Timeline"
    static var description = IntentDescription("Your timeline at a glance.")

    @Parameter(title: "Show Streaks", default: true)
    var showStreaks: Bool
}

// MARK: - Widget Ma Colors (for Widget context)

struct WidgetMaColors {
    // Adaptive colors for widgets
    static let primary = Color(light: Color(hex: "7EB8DA"), dark: Color(hex: "5BA3C9"))
    static let complete = Color(light: Color(hex: "8FBC8F"), dark: Color(hex: "6B9B6B"))
    static let overdue = Color(light: Color(hex: "E88B8B"), dark: Color(hex: "D47A7A"))
    static let streak = Color(light: Color(hex: "F5A855"), dark: Color(hex: "E89845"))
    static let xp = Color(light: Color(hex: "A68BC8"), dark: Color(hex: "9678B8"))

    static let background = Color(light: Color(hex: "FAF8F5"), dark: Color(hex: "1A1918"))
    static let backgroundSecondary = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "252423"))

    static let textPrimary = Color(light: Color(hex: "2D2A26"), dark: Color(hex: "F5F3F0"))
    static let textSecondary = Color(light: Color(hex: "6B6560"), dark: Color(hex: "A8A5A0"))
    static let textTertiary = Color(light: Color(hex: "A8A5A0"), dark: Color(hex: "6B6560"))
}

// Color extension for widget (supports light/dark)
extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

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

// MARK: - Widget Views

struct LifeOpsWidgetEntryView: View {
    var entry: MaTimelineEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            MaSmallWidgetView(entry: entry)
        case .systemMedium:
            MaMediumWidgetView(entry: entry)
        case .systemLarge:
            MaLargeWidgetView(entry: entry)
        case .accessoryCircular:
            MaCircularWidgetView(entry: entry)
        case .accessoryRectangular:
            MaRectangularWidgetView(entry: entry)
        case .accessoryInline:
            MaInlineWidgetView(entry: entry)
        default:
            MaMediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct MaSmallWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "leaf")
                    .font(.caption)
                    .foregroundStyle(WidgetMaColors.primary)
                Text("Ma")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(WidgetMaColors.textPrimary)
            }

            Spacer()

            // Next item or empty state
            if let item = entry.items.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if item.isOverdue {
                            Circle()
                                .fill(WidgetMaColors.overdue)
                                .frame(width: 6, height: 6)
                        }
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(WidgetMaColors.textPrimary)
                            .lineLimit(2)
                    }

                    if let time = item.time {
                        Text(formatTime(time))
                            .font(.caption2)
                            .foregroundStyle(WidgetMaColors.textSecondary)
                    }

                    if item.streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(WidgetMaColors.streak)
                            Text("\(item.streak)")
                                .foregroundStyle(WidgetMaColors.streak)
                        }
                        .font(.caption2)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(WidgetMaColors.complete)
                    Text("All clear")
                        .font(.caption2)
                        .foregroundStyle(WidgetMaColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()

            // Count
            if entry.items.count > 1 {
                Text("+\(entry.items.count - 1) more")
                    .font(.caption2)
                    .foregroundStyle(WidgetMaColors.textTertiary)
            }
        }
        .padding()
        .containerBackground(WidgetMaColors.background, for: .widget)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Medium Widget

struct MaMediumWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "leaf")
                        .foregroundStyle(WidgetMaColors.primary)
                    Text("Ma Timeline")
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetMaColors.textPrimary)
                }
                .font(.subheadline)

                Spacer()

                Text(entry.items.isEmpty ? "All clear" : "\(entry.items.count) items")
                    .font(.caption)
                    .foregroundStyle(WidgetMaColors.textSecondary)
            }

            if entry.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(WidgetMaColors.complete)
                        Text("Take a breath")
                            .font(.caption)
                            .foregroundStyle(WidgetMaColors.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Show up to 3 items
                ForEach(entry.items.prefix(3)) { item in
                    MaWidgetItemRow(item: item, showStreak: entry.configuration.showStreaks)
                }

                if entry.items.count > 3 {
                    Text("+\(entry.items.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(WidgetMaColors.textTertiary)
                }
            }
        }
        .padding()
        .containerBackground(WidgetMaColors.background, for: .widget)
    }
}

// MARK: - Large Widget

struct MaLargeWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf")
                        .foregroundStyle(WidgetMaColors.primary)
                    Text("Ma Timeline")
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetMaColors.textPrimary)
                }
                .font(.headline)

                Spacer()

                Text(Date(), style: .time)
                    .font(.caption)
                    .foregroundStyle(WidgetMaColors.textSecondary)
            }

            Rectangle()
                .fill(WidgetMaColors.textTertiary.opacity(0.3))
                .frame(height: 1)

            if entry.items.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(WidgetMaColors.complete)
                    Text("All caught up")
                        .font(.headline)
                        .foregroundStyle(WidgetMaColors.textPrimary)
                    Text("This is your Ma")
                        .font(.caption)
                        .foregroundStyle(WidgetMaColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Show up to 6 items
                ForEach(entry.items.prefix(6)) { item in
                    MaWidgetItemRow(item: item, showStreak: entry.configuration.showStreaks)

                    if item.id != entry.items.prefix(6).last?.id {
                        Rectangle()
                            .fill(WidgetMaColors.textTertiary.opacity(0.2))
                            .frame(height: 1)
                    }
                }

                Spacer()

                if entry.items.count > 6 {
                    Text("+\(entry.items.count - 6) more items")
                        .font(.caption)
                        .foregroundStyle(WidgetMaColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .containerBackground(WidgetMaColors.background, for: .widget)
    }
}

// MARK: - Widget Item Row

struct MaWidgetItemRow: View {
    let item: WidgetItem
    let showStreak: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(item.isOverdue ? WidgetMaColors.overdue : WidgetMaColors.primary)
                .frame(width: 8, height: 8)

            // Icon
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(WidgetMaColors.textSecondary)
                    .frame(width: 16)
            }

            // Title
            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(WidgetMaColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Time
            if let time = item.time {
                Text(formatTime(time))
                    .font(.caption2)
                    .foregroundStyle(WidgetMaColors.textSecondary)
            }

            // Streak
            if showStreak && item.streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                    Text("\(item.streak)")
                }
                .font(.caption2)
                .foregroundStyle(WidgetMaColors.streak)
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

struct MaCircularWidgetView: View {
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
                    Text("tasks")
                        .font(.caption2)
                }
            }
        }
    }
}

struct MaRectangularWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        if let item = entry.items.first {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
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
                Text("All clear")
            }
        }
    }
}

struct MaInlineWidgetView: View {
    let entry: MaTimelineEntry

    var body: some View {
        if let item = entry.items.first {
            Text("\(entry.items.count) tasks | \(item.title)")
        } else {
            Text("All clear")
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
    let kind: String = "MaTimeline"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: TimelineProvider()
        ) { entry in
            LifeOpsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ma Timeline")
        .description("Your timeline at a glance.")
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
