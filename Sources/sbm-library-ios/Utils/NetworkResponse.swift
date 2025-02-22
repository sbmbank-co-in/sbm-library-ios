import Foundation

public struct NetworkResponse: Sendable {
    let data: [String: SendableValue]
    
    init(dictionary: [String: Any]) {
        self.data = dictionary.mapValues { SendableValue($0) }
    }
    
    public func getValue(forKey key: String) -> Any? {
        return data[key]?.value
    }
    
    public func getString(forKey key: String) -> String? {
        return getValue(forKey: key) as? String
    }
    
    public func getInt(forKey key: String) -> Int? {
        return getValue(forKey: key) as? Int
    }
}

// Helper enum to make dictionary values Sendable
public enum SendableValue: Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null
    case array([SendableValue])
    case dictionary([String: SendableValue])
    
    init(_ value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            self = .array(array.map { SendableValue($0) })
        case let dict as [String: Any]:
            self = .dictionary(dict.mapValues { SendableValue($0) })
        default:
            self = .null
        }
    }
    
    var value: Any {
        switch self {
        case .string(let string): return string
        case .int(let int): return int
        case .bool(let bool): return bool
        case .null: return NSNull()
        case .array(let array): return array.map { $0.value }
        case .dictionary(let dict): return dict.mapValues { $0.value }
        }
    }
}
