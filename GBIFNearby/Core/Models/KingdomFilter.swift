import Foundation

enum KingdomFilter: String, CaseIterable, Sendable, Codable {
    case all
    case animals
    case plants
    case fungi

    var taxonKey: Int? {
        switch self {
        case .all: return nil
        case .animals: return 1
        case .plants: return 6
        case .fungi: return 5
        }
    }

    var displayLabel: String {
        switch self {
        case .all: return "All"
        case .animals: return "Animals"
        case .plants: return "Plants"
        case .fungi: return "Fungi"
        }
    }

    var sfSymbol: String {
        switch self {
        case .all: return "globe.europe.africa"
        case .animals: return "pawprint.fill"
        case .plants: return "leaf.fill"
        case .fungi: return "allergens"
        }
    }
}
