import Foundation

class EventStorage {
    private static let key = "analytics_events_spense"
    private let userDefaults = UserDefaults.standard

    func loadEvents() throws -> [AnalyticsEvent] {
        guard let jsonString = userDefaults.string(forKey: Self.key) else {
            return []
        }
        return try AnalyticsEvent.listFromJson(jsonString)
    }

    func saveEvents(_ events: [AnalyticsEvent]) throws {
        let jsonString = try AnalyticsEvent.listToJson(events)
        userDefaults.set(jsonString, forKey: Self.key)
    }

    func clearEvents() {
        userDefaults.removeObject(forKey: Self.key)
    }
}
