// TimelineModels.swift
// Shared models for Timeline feature - matches LifeOps API

import Foundation

// MARK: - Timeline Feed

struct TimelineFeed: Codable {
    let items: [TimelineFeedItem]
    let currentTime: Date
    let windowStart: Date
    let windowEnd: Date
    let overdue: [TimelineFeedItem]
    let upcoming: [TimelineFeedItem]
    let completed: [TimelineFeedItem]

    enum CodingKeys: String, CodingKey {
        case items
        case currentTime = "current_time"
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case overdue
        case upcoming
        case completed
    }
}

// MARK: - Timeline Item

struct TimelineFeedItem: Codable, Identifiable {
    let id: String
    let code: String
    let title: String
    let description: String?
    let icon: String?
    let color: String?
    let timeAnchor: String?
    let scheduledTime: Date?
    let windowMinutes: Int
    let status: ItemStatus
    let isOverdue: Bool
    let currentStreak: Int
    let bestStreak: Int
    let xpReward: Int
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id, code, title, description, icon, color
        case timeAnchor = "time_anchor"
        case scheduledTime = "scheduled_time"
        case windowMinutes = "window_minutes"
        case status
        case isOverdue = "is_overdue"
        case currentStreak = "current_streak"
        case bestStreak = "best_streak"
        case xpReward = "xp_reward"
        case category
    }
}

enum ItemStatus: String, Codable {
    case pending
    case active
    case completed
    case skipped
    case postponed
}

// MARK: - Timeline Item (Full)

struct TimelineItem: Codable, Identifiable {
    let id: String
    let code: String
    let title: String
    let description: String?
    let icon: String?
    let color: String?
    let timeAnchor: String?
    let defaultTime: String?  // "HH:mm" format
    let windowMinutes: Int
    let recurrence: String?
    let xpReward: Int
    let category: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, code, title, description, icon, color
        case timeAnchor = "time_anchor"
        case defaultTime = "default_time"
        case windowMinutes = "window_minutes"
        case recurrence
        case xpReward = "xp_reward"
        case category
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Actions

struct CompleteRequest: Codable {
    let notes: String?
    let quality: Int?  // 1-5 rating

    init(notes: String? = nil, quality: Int? = nil) {
        self.notes = notes
        self.quality = quality
    }
}

struct CompleteResponse: Codable {
    let success: Bool
    let xpGranted: Int
    let newStreak: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case xpGranted = "xp_granted"
        case newStreak = "new_streak"
        case message
    }
}

struct PostponeRequest: Codable {
    let target: PostponeTarget
    let customDate: Date?
    let customTime: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case target
        case customDate = "custom_date"
        case customTime = "custom_time"
        case reason
    }
}

enum PostponeTarget: String, Codable, CaseIterable {
    case lunch
    case afternoon
    case afterWork = "after_work"
    case evening
    case tonight
    case tomorrow
    case tomorrowMorning = "tomorrow_morning"
    case nextWeek = "next_week"
    case custom

    var displayName: String {
        switch self {
        case .lunch: return "Lunch"
        case .afternoon: return "Afternoon"
        case .afterWork: return "After Work"
        case .evening: return "Evening"
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        case .tomorrowMorning: return "Tomorrow Morning"
        case .nextWeek: return "Next Week"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .lunch: return "fork.knife"
        case .afternoon: return "sun.max"
        case .afterWork: return "briefcase"
        case .evening: return "sunset"
        case .tonight: return "moon"
        case .tomorrow: return "sunrise"
        case .tomorrowMorning: return "alarm"
        case .nextWeek: return "calendar"
        case .custom: return "calendar.badge.clock"
        }
    }
}

struct PostponeResponse: Codable {
    let success: Bool
    let newTime: Date
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case newTime = "new_time"
        case message
    }
}

// MARK: - Time Anchors

struct TimeAnchor: Codable, Identifiable {
    let id: String
    let code: String
    let name: String
    let time: String  // "HH:mm" format
    let description: String?
}

// MARK: - Create Item

struct TimelineItemCreate: Codable {
    let code: String
    let title: String
    let description: String?
    let icon: String?
    let color: String?
    let timeAnchor: String?
    let defaultTime: String?
    let windowMinutes: Int
    let recurrence: String?
    let xpReward: Int
    let category: String?

    enum CodingKeys: String, CodingKey {
        case code, title, description, icon, color
        case timeAnchor = "time_anchor"
        case defaultTime = "default_time"
        case windowMinutes = "window_minutes"
        case recurrence
        case xpReward = "xp_reward"
        case category
    }
}
