import Foundation
import Combine

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()

    private let baseURL = "https://smart-billing-dashboard.azurewebsites.net"
    @Published var isAuthenticated = false
    private var password: String = ""

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "dashboard_password"), !saved.isEmpty {
            password = saved
            isAuthenticated = true
        }
    }

    // MARK: - Auth

    func login(password: String) async throws {
        let url = URL(string: "\(baseURL)/api/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["password": password])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.unauthorized
        }

        self.password = password
        self.isAuthenticated = true
        UserDefaults.standard.set(password, forKey: "dashboard_password")
    }

    func logout() {
        password = ""
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "dashboard_password")
    }

    // MARK: - Generic Fetch

    private func fetch<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "\(baseURL)/\(path)")!
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "token", value: password))
        components.queryItems = items.isEmpty ? nil : items

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(password)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { self.isAuthenticated = false }
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func queryParams(filter: DateRangeFilter, app: String? = nil) -> [String: String] {
        var params: [String: String] = [:]
        let (from, to) = filter.queryParams
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        if let app, !app.isEmpty { params["app"] = app }
        return params
    }

    // MARK: - Endpoints

    func fetchApps() async throws -> [AppInfo] {
        try await fetch("api/apps")
    }

    func fetchOverview(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> OverviewResponse {
        try await fetch("api/overview", query: queryParams(filter: filter, app: app))
    }

    func fetchPlans(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> PlansResponse {
        try await fetch("api/plans", query: queryParams(filter: filter, app: app))
    }

    func fetchCountries(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> [CountryData] {
        try await fetch("api/countries", query: queryParams(filter: filter, app: app))
    }

    func fetchSubscribers(filter: DateRangeFilter = .allTime, app: String? = nil, status: String? = nil, tier: String? = nil) async throws -> SubscribersResponse {
        var params = queryParams(filter: filter, app: app)
        if let status { params["status"] = status }
        if let tier { params["tier"] = tier }
        return try await fetch("api/subscribers", query: params)
    }

    func fetchSubscriberDetail(id: String) async throws -> SubscriberDetail {
        try await fetch("api/subscriber/\(id)")
    }

    func fetchDownloads(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> DownloadsResponse {
        try await fetch("api/downloads", query: queryParams(filter: filter, app: app))
    }

    func fetchAppLaunches(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> AppLaunchesResponse {
        try await fetch("api/app-launches", query: queryParams(filter: filter, app: app))
    }

    func fetchTimeline(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> TimelineResponse {
        try await fetch("api/timeline", query: queryParams(filter: filter, app: app))
    }

    func fetchTrends(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> [TrendMonth] {
        try await fetch("api/trends", query: queryParams(filter: filter, app: app))
    }

    func fetchRetention(filter: DateRangeFilter = .allTime, app: String? = nil) async throws -> [RetentionCohort] {
        try await fetch("api/retention", query: queryParams(filter: filter, app: app))
    }

    func refresh() async throws {
        let url = URL(string: "\(baseURL)/api/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(password)", forHTTPHeaderField: "Authorization")
        let _ = try await URLSession.shared.data(for: request)
    }
}

enum APIError: LocalizedError {
    case unauthorized
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Invalid password"
        case .decodingError(let err): return "Data error: \(err.localizedDescription)"
        }
    }
}
