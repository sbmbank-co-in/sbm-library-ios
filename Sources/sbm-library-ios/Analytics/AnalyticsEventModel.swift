import Foundation

struct AnalyticsEvent: Codable {
    let time: String
    let info: [String: Any]
    let device: [String: Any]

    enum CodingKeys: String, CodingKey {
        case time
        case event

    }

    enum EventKeys: String, CodingKey {
        case info
        case device
    }

    init(time: String, info: [String: Any], device: [String: Any]) {
        self.time = time
        self.info = info
        self.device = device

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time, forKey: .time)

        var eventContainer = container.nestedContainer(keyedBy: EventKeys.self, forKey: .event)
        try eventContainer.encode(info.mapValues { String(describing: $0) }, forKey: .info)
        try eventContainer.encode(device.mapValues { String(describing: $0) }, forKey: .device)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode(String.self, forKey: .time)

        let eventContainer = try container.nestedContainer(keyedBy: EventKeys.self, forKey: .event)
        info = try eventContainer.decode([String: Any].self, forKey: .info)
        device = try eventContainer.decode([String: Any].self, forKey: .device)
    }

    static func listFromJson(_ jsonString: String) throws -> [AnalyticsEvent] {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(
                domain: "AnalyticsEvent", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        return try JSONDecoder().decode([AnalyticsEvent].self, from: data)
    }

    static func listToJson(_ events: [AnalyticsEvent]) throws -> String {
        let data = try JSONEncoder().encode(events)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "AnalyticsEvent", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert to JSON string"])
        }
        return jsonString
    }
}

// Extension to handle [String: Any] coding
extension KeyedDecodingContainer {
    func decode(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any] {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        var dictionary: [String: Any] = [:]

        for key in container.allKeys {
            if let boolValue = try? container.decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            } else if let stringValue = try? container.decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            } else if let intValue = try? container.decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            } else if let doubleValue = try? container.decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            } else if let nestedDictionary = try? container.decode([String: Any].self, forKey: key)
            {
                dictionary[key.stringValue] = nestedDictionary
            }
        }
        return dictionary
    }
}

extension KeyedEncodingContainer {
    mutating func encode(_ value: [String: Any], forKey key: K) throws {
        var container = self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)

        for (key, value) in value {
            guard let codingKey = JSONCodingKeys(stringValue: key) else { continue }

            switch value {
            case let value as Bool:
                try container.encode(value, forKey: codingKey)
            case let value as String:
                try container.encode(value, forKey: codingKey)
            case let value as Int:
                try container.encode(value, forKey: codingKey)
            case let value as Double:
                try container.encode(value, forKey: codingKey)
            case let value as [String: Any]:
                try container.encode(value, forKey: codingKey)
            default:
                try container.encode(String(describing: value), forKey: codingKey)
            }
        }
    }
}

// Helper for dynamic keys
struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
