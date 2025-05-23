import Foundation
import SwiftUI
import UIKit

@available(iOS 13.0, *)
public class AnalyticsLogger {
    // Singleton setup
    static let shared = AnalyticsLogger()
    private init() {}

    private let eventStorage = EventStorage()
    private var events: [AnalyticsEvent] = []

    private var debounceTimer: Timer?
    private var lastPost: TimeInterval = 0

    private let maxBatchSize = 100
    private let maxInterval: TimeInterval = 600  // 10 minutes
    private let queue = DispatchQueue(label: "com.analytics.logger")

    public static func logEvent(_ info: [String: Any]) {
        Task {
            await shared.logEvent(info: info)
        }
    }

    private func loadEvents() async throws -> [AnalyticsEvent] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let events = try self.eventStorage.loadEvents()
                    continuation.resume(returning: events)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func saveEvents(_ events: [AnalyticsEvent]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.eventStorage.saveEvents(events)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func logEvent(info: [String: Any]) async {
        do {
            let deviceInfo = await getDeviceInfo()
            let now = ISO8601DateFormatter().string(from: Date())

            var modifiedInfo = info
            modifiedInfo["framework"] = "IOS"

            let event = AnalyticsEvent(
                time: now,
                info: modifiedInfo,
                device: deviceInfo
            )

            var currentEvents = try await loadEvents()
            currentEvents.append(event)
            try await saveEvents(currentEvents)

            let currentTime = Date().timeIntervalSince1970
            if currentEvents.count >= maxBatchSize || (currentTime - lastPost > maxInterval) {
                try await post()
            } else {
                debouncePost()
            }
        } catch {
            print("Error logging event: \(error)")
        }
    }

    private func getDeviceInfo() async -> [String: Any] {
        return [
            "device_uuid": await UIDevice.current.identifierForVendor?.uuidString ?? "",
            "manufacturer": "Apple",
            "model": await UIDevice.modelName,
            "os": "iOS",
            "os_version": await UIDevice.current.systemVersion,
            "app_version": PackageInfo.version,
        ]
    }

    private func debouncePost() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) {
            [weak self] _ in
            Task {
                try? await self?.post()
            }
        }
    }

    private func post() async throws {
        let currentEvents = try await loadEvents()
        guard !currentEvents.isEmpty else { return }

        do {
            print("Calling analytics API")

            let eventsData = currentEvents.map { event -> [String: Any] in
                return [
                    "time": event.time,
                    "event": [
                        "info": event.info,
                        "device": event.device,
                    ],
                ]
            }

            lastPost = Date().timeIntervalSince1970

            print("Analytics payload: \(["data": eventsData])")
            let response = try await NetworkManager.shared.makeRequest(
                url: URL(string: ServiceNames.ANALYTICS)!,
                method: "POST",
                jsonPayload: ["data": eventsData]
            )

            try await eventStorage.clearEvents()
            print("Analytics API response: \(response)")
        } catch {
            print("Error posting analytics: \(error)")

            // Save the current events back for retrying later
            do {
                try await saveEvents(currentEvents)
            } catch {
                print("Failed to save events after post failure: \(error)")
            }
        }

    }

}
