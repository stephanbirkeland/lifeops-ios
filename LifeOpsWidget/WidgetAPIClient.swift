// WidgetAPIClient.swift
// Simplified API client for widget extension

import Foundation

// MARK: - Widget API Client

class WidgetAPIClient {
    static let shared = WidgetAPIClient()

    private let decoder: JSONDecoder

    // Use App Group to share auth tokens with main app
    private var accessToken: String? {
        UserDefaults(suiteName: "group.com.lifeops.app")?.string(forKey: "access_token")
    }

    private var baseURL: String {
        UserDefaults(suiteName: "group.com.lifeops.app")?.string(forKey: "api_base_url")
            ?? "http://localhost:8000"
    }

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func getTimeline() async throws -> TimelineFeed {
        guard let url = URL(string: "\(baseURL)/timeline?hours=4") else {
            throw WidgetError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WidgetError.requestFailed
        }

        return try decoder.decode(TimelineFeed.self, from: data)
    }
}

enum WidgetError: Error {
    case invalidURL
    case requestFailed
    case decodingError
}
