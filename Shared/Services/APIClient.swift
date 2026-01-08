// APIClient.swift
// LifeOps API client for iOS/watchOS

import Foundation

// MARK: - API Configuration

struct APIConfig {
    static var baseURL: String {
        // Use localhost for simulator, configure for real device
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        // For real device, use Tailscale IP to reach the backend
        return UserDefaults.standard.string(forKey: "api_base_url") ?? "http://100.105.78.116:8000"
        #endif
    }

    static var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "access_token") }
    }

    static var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "refresh_token") }
    }
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, String)
    case unauthorized
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .notFound:
            return "Resource not found"
        }
    }
}

// MARK: - API Client

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    @Published var isAuthenticated = false

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Check for existing token
        isAuthenticated = APIConfig.accessToken != nil
    }

    // MARK: - Request Building

    private func buildRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        var components = URLComponents(string: APIConfig.baseURL + path)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = APIConfig.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    // MARK: - Request Execution

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "HTTP", code: 0))
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            isAuthenticated = false
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    private func executeNoContent(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "HTTP", code: 0))
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            isAuthenticated = false
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }
}

// MARK: - Timeline API

extension APIClient {

    /// Get the rolling timeline feed
    func getTimeline(hours: Int = 4, expand: Bool = false, forDate: Date? = nil) async throws -> TimelineFeed {
        var queryItems = [
            URLQueryItem(name: "hours", value: String(hours)),
            URLQueryItem(name: "expand", value: String(expand))
        ]

        if let date = forDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "for_date", value: formatter.string(from: date)))
        }

        let request = try buildRequest(path: "/timeline", queryItems: queryItems)
        return try await execute(request)
    }

    /// Get full day timeline
    func getFullDayTimeline(forDate: Date? = nil) async throws -> TimelineFeed {
        var queryItems: [URLQueryItem] = []

        if let date = forDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "for_date", value: formatter.string(from: date)))
        }

        let request = try buildRequest(path: "/timeline/day", queryItems: queryItems)
        return try await execute(request)
    }

    /// Complete a timeline item
    func completeItem(code: String, notes: String? = nil, quality: Int? = nil) async throws -> CompleteResponse {
        let body = CompleteRequest(notes: notes, quality: quality)
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(path: "/timeline/\(code)/complete", method: "POST", body: bodyData)
        return try await execute(request)
    }

    /// Postpone a timeline item
    func postponeItem(code: String, target: PostponeTarget, reason: String? = nil) async throws -> PostponeResponse {
        let body = PostponeRequest(target: target, customDate: nil, customTime: nil, reason: reason)
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(path: "/timeline/\(code)/postpone", method: "POST", body: bodyData)
        return try await execute(request)
    }

    /// Skip a timeline item
    func skipItem(code: String, reason: String? = nil) async throws {
        var queryItems: [URLQueryItem] = []
        if let reason = reason {
            queryItems.append(URLQueryItem(name: "reason", value: reason))
        }
        let request = try buildRequest(path: "/timeline/\(code)/skip", method: "POST", queryItems: queryItems)
        try await executeNoContent(request)
    }

    /// List all timeline items
    func listItems(activeOnly: Bool = true) async throws -> [TimelineItem] {
        let queryItems = [URLQueryItem(name: "active_only", value: String(activeOnly))]
        let request = try buildRequest(path: "/timeline/items", queryItems: queryItems)
        return try await execute(request)
    }

    /// Create a new timeline item
    func createItem(_ item: TimelineItemCreate) async throws -> TimelineItem {
        let bodyData = try encoder.encode(item)
        let request = try buildRequest(path: "/timeline/items", method: "POST", body: bodyData)
        return try await execute(request)
    }

    /// Get time anchors
    func getAnchors() async throws -> [TimeAnchor] {
        let request = try buildRequest(path: "/timeline/anchors")
        return try await execute(request)
    }
}

// MARK: - Auth API

extension APIClient {

    struct LoginResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
        }
    }

    struct LoginRequest: Codable {
        let username: String
        let password: String
    }

    func login(username: String, password: String) async throws {
        let body = LoginRequest(username: username, password: password)
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(path: "/auth/login", method: "POST", body: bodyData)
        let response: LoginResponse = try await execute(request)

        APIConfig.accessToken = response.accessToken
        APIConfig.refreshToken = response.refreshToken
        isAuthenticated = true
    }

    func logout() {
        APIConfig.accessToken = nil
        APIConfig.refreshToken = nil
        isAuthenticated = false
    }
}

// MARK: - Health API

extension APIClient {

    struct HealthResponse: Codable {
        let status: String
        let timestamp: Date?
        let version: String
    }

    func checkHealth() async throws -> HealthResponse {
        let request = try buildRequest(path: "/health")
        return try await execute(request)
    }
}
