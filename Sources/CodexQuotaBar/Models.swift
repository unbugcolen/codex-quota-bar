import Foundation

struct AppServerRateLimitsResponse: Decodable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?

    var codexRateLimits: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
    }
}

struct RateLimitSnapshot: Decodable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let planType: String?
    let rateLimitReachedType: String?
}

struct RateLimitWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?
}

struct QuotaSnapshot {
    let fiveHour: QuotaBucket
    let weekly: QuotaBucket
    let planType: String?
    let updatedAt: Date

    init(rateLimits: RateLimitSnapshot, now: Date = Date()) {
        let windows = [rateLimits.primary, rateLimits.secondary].compactMap { $0 }
        let fiveHourWindow = QuotaSnapshot.window(closestTo: 300, in: windows) ?? rateLimits.primary
        let weeklyWindow = QuotaSnapshot.window(closestTo: 10_080, in: windows) ?? rateLimits.secondary

        self.fiveHour = QuotaBucket(title: "5小时", window: fiveHourWindow)
        self.weekly = QuotaBucket(title: "周限额", window: weeklyWindow)
        self.planType = rateLimits.planType
        self.updatedAt = now
    }

    private static func window(closestTo minutes: Int, in windows: [RateLimitWindow]) -> RateLimitWindow? {
        windows
            .filter { $0.windowDurationMins != nil }
            .min { lhs, rhs in
                abs((lhs.windowDurationMins ?? minutes) - minutes) < abs((rhs.windowDurationMins ?? minutes) - minutes)
            }
    }
}

struct QuotaBucket {
    let title: String
    let usedPercent: Double?
    let remainingPercent: Double?
    let resetDate: Date?

    init(title: String, window: RateLimitWindow?) {
        self.title = title
        self.usedPercent = window?.usedPercent
        if let usedPercent = window?.usedPercent {
            self.remainingPercent = min(100, max(0, 100 - usedPercent))
        } else {
            self.remainingPercent = nil
        }
        if let resetsAt = window?.resetsAt {
            self.resetDate = Date(timeIntervalSince1970: resetsAt)
        } else {
            self.resetDate = nil
        }
    }
}
