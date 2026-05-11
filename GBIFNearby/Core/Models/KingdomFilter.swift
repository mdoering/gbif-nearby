import Foundation

enum KingdomFilter: String, CaseIterable, Sendable, Codable {
    case animals
    case plants
    case fungi

    /// Taxon key for this kingdom on the GBIF backbone. Always non-nil for these three.
    var taxonKey: Int {
        switch self {
        case .animals: return 1
        case .plants: return 6
        case .fungi: return 5
        }
    }

    var displayLabel: String {
        switch self {
        case .animals: return "Animals"
        case .plants: return "Plants"
        case .fungi: return "Fungi"
        }
    }

    /// Rendering hint for the chip icon. SF Symbols cover Animals/Plants well, but
    /// "allergens" reads as a peanut, not a mushroom. Use Apple's Amanita-muscaria
    /// emoji for Fungi instead.
    enum Icon: Sendable {
        case sfSymbol(String)
        case emoji(String)
    }

    var icon: Icon {
        switch self {
        case .animals: return .sfSymbol("pawprint.fill")
        case .plants: return .sfSymbol("leaf.fill")
        case .fungi: return .emoji("🍄")
        }
    }
}
