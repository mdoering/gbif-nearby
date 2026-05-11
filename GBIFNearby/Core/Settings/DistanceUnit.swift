import Foundation

enum DistanceUnit: String, CaseIterable, Sendable, Codable {
    case kilometers
    case miles

    var displayName: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }

    var symbol: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }

    static func fromLocale() -> DistanceUnit {
        Locale.current.measurementSystem == .metric ? .kilometers : .miles
    }
}
