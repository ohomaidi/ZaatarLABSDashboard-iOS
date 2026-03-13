import Foundation

// MARK: - Overview

struct OverviewResponse: Codable {
    let activeSubscribers: Int
    let totalSubscribers: Int
    let mrr: Double
    let totalRevenue: Double
    let churnRate: Double
    let newInPeriod: Int
    let billingIssues: Int
    let refunded: Int
    let expired: Int
}

// MARK: - Plans

struct PlansResponse: Codable {
    let plans: [Plan]
    let tiers: [String: Int]
    let periods: [String: Int]
}

struct Plan: Codable, Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let mrr: Double
    let tier: String
    let period: String
}

// MARK: - Countries

struct CountryData: Codable, Identifiable {
    var id: String { country }
    let country: String
    let count: Int
    let mrr: Double
}

// MARK: - Subscribers

struct SubscribersResponse: Codable {
    let subscribers: [Subscriber]
    let total: Int
}

struct Subscriber: Codable, Identifiable {
    var id: String { subscriberId }
    let subscriberId: String
    let status: String
    let tier: String
    let period: String
    let productName: String
    let storefront: String
    let firstPurchase: String
    let lastEvent: String
    let expiresDate: String?
    let autoRenew: Bool
    let totalRevenue: Double
    let eventCount: Int

    enum CodingKeys: String, CodingKey {
        case subscriberId = "id"
        case status, tier, period, productName, storefront
        case firstPurchase, lastEvent, expiresDate, autoRenew
        case totalRevenue, eventCount
    }
}

// MARK: - Subscriber Detail

struct SubscriberDetail: Codable {
    let id: String
    let events: [SubscriberEvent]
    let currentProductName: String?
    let tier: String?
    let period: String?
    let status: String?
    let storefront: String?
    let firstPurchase: String?
    let lastEvent: String?
    let expiresDate: String?
    let autoRenew: Bool?
    let totalRevenue: Double?
    let currency: String?
}

struct SubscriberEvent: Codable, Identifiable {
    var id: String { "\(type)-\(storedAt ?? purchaseDate ?? UUID().uuidString)" }
    let type: String
    let subtype: String?
    let productName: String?
    let price: Double?
    let currency: String?
    let purchaseDate: String?
    let expiresDate: String?
    let storedAt: String?
    let storefront: String?
}

// MARK: - Downloads (Apple Data)

struct DownloadsResponse: Codable {
    let configured: Bool
    let message: String?
    let totalDownloads: Int?
    let totalUpdates: Int?
    let totalRedownloads: Int?
    let daily: [DailyDownload]?
    let monthly: [MonthlyDownload]?
    let countries: [DownloadCountry]?
    let devices: [DownloadDevice]?
}

struct DailyDownload: Codable, Identifiable {
    var id: String { date }
    let date: String
    let downloads: Int
    let updates: Int
    let redownloads: Int
    let iap: Int?
}

struct MonthlyDownload: Codable, Identifiable {
    var id: String { month }
    let month: String
    let downloads: Int
    let updates: Int
}

struct DownloadCountry: Codable, Identifiable {
    var id: String { country }
    let country: String
    let units: Int
}

struct DownloadDevice: Codable, Identifiable {
    var id: String { device }
    let device: String
    let units: Int
}

// MARK: - App Launches (App Reporting)

struct AppLaunchesResponse: Codable {
    let totalLaunches: Int
    let firstInstalls: Int
    let redownloads: Int
    let daily: [DailyLaunch]
    let devices: [LaunchDevice]
    let categories: [LaunchCategory]
    let recent: [RecentLaunch]
}

struct DailyLaunch: Codable, Identifiable {
    var id: String { date }
    let date: String
    let firstInstalls: Int
    let redownloads: Int
}

struct LaunchDevice: Codable, Identifiable {
    var id: String { device }
    let device: String
    let count: Int
}

struct LaunchCategory: Codable, Identifiable {
    var id: String { category }
    let category: String
    let count: Int
}

struct RecentLaunch: Codable, Identifiable {
    var id: String { "\(deviceId ?? "")-\(launchedAt ?? "")" }
    let deviceId: String?
    let bundleId: String?
    let launchedAt: String?
    let isRedownload: Bool
    let appVersion: String?
    let osVersion: String?
    let deviceModel: String?
    let deviceCategory: String?
    let locale: String?
}

// MARK: - Timeline (Activity)

struct TimelineResponse: Codable {
    let timeline: [TimelineEvent]
    let total: Int
}

struct TimelineEvent: Codable, Identifiable {
    var id: String { "\(originalTransactionId ?? "")-\(storedAt ?? UUID().uuidString)" }
    let type: String
    let subtype: String?
    let productId: String?
    let productName: String?
    let originalTransactionId: String?
    let storefront: String?
    let price: Double?
    let currency: String?
    let purchaseDate: String?
    let expiresDate: String?
    let storedAt: String?
    let autoRenew: Bool?
    let environment: String?
}

// MARK: - Trends

struct TrendMonth: Codable, Identifiable {
    var id: String { month }
    let month: String
    let subscribed: Int
    let renewed: Int
    let expired: Int
    let refunded: Int
    let revenue: Double
}

// MARK: - Retention

struct RetentionCohort: Codable, Identifiable {
    var id: String { month }
    let month: String
    let total: Int
    let retention: [String: Double]
}

// MARK: - Apps

struct AppInfo: Codable, Identifiable, Hashable {
    var id: String { bundleId }
    let bundleId: String
    let displayName: String
}

// MARK: - Notifications

struct StoredNotification: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let receivedAt: Date
}

// MARK: - Helpers

enum DateRangeFilter: String, CaseIterable {
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case allTime = "All Time"

    var queryParams: (from: String?, to: String?) {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .thisMonth:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            return (iso(start), nil)
        case .lastMonth:
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let lastMonth = cal.date(byAdding: .month, value: -1, to: thisMonth)!
            return (iso(lastMonth), iso(thisMonth))
        case .thisYear:
            let start = cal.date(from: DateComponents(year: cal.component(.year, from: now)))!
            return (iso(start), nil)
        case .allTime:
            return (nil, nil)
        }
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }
}

extension String {
    /// Formats an ISO date string to a short display format
    var shortDate: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f.date(from: self) {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        // Try without fractional seconds
        f.formatOptions = [.withInternetDateTime]
        if let date = f.date(from: self) {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        return self
    }

    var shortDateOnly: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f.date(from: self) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            return df.string(from: date)
        }
        return self
    }
}
