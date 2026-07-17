import Foundation

enum StatusDisplayMode: String, CaseIterable {
    case miniProgress
    case compactProgress
    case singleProgress
    case dualProgress = "progress"
    case text

    var title: String {
        switch self {
        case .miniProgress:
            return "迷你文字"
        case .compactProgress:
            return "紧凑进度"
        case .singleProgress:
            return "单条进度"
        case .dualProgress:
            return "双条进度"
        case .text:
            return "文字"
        }
    }
}

struct UserSettings {
    var statusDisplayMode: StatusDisplayMode
    var refreshIntervalSeconds: TimeInterval

    static let refreshIntervalOptions: [TimeInterval] = [60, 300, 600, 1_800]

    static func load(defaults: UserDefaults = .standard) -> UserSettings {
        let mode = defaults.string(forKey: Keys.statusDisplayMode)
            .flatMap(StatusDisplayMode.init(rawValue:)) ?? .miniProgress
        let interval = defaults.double(forKey: Keys.refreshIntervalSeconds)
        return UserSettings(
            statusDisplayMode: mode,
            refreshIntervalSeconds: interval > 0 ? interval : 300
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(statusDisplayMode.rawValue, forKey: Keys.statusDisplayMode)
        defaults.set(refreshIntervalSeconds, forKey: Keys.refreshIntervalSeconds)
    }

    static func title(for interval: TimeInterval) -> String {
        switch Int(interval) {
        case 60:
            return "1 分钟"
        case 300:
            return "5 分钟"
        case 600:
            return "10 分钟"
        case 1_800:
            return "30 分钟"
        default:
            return "\(Int(interval / 60)) 分钟"
        }
    }

    private enum Keys {
        static let statusDisplayMode = "statusDisplayMode"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
    }
}
