import Foundation
import Observation

@MainActor
@Observable
final class TaxonFilterStore {
    static let key = "kingdomFilter"
    private let defaults: UserDefaults

    /// Selected kingdom chip. `nil` means no kingdom filter.
    var selected: KingdomFilter? {
        didSet {
            if let raw = selected?.rawValue {
                defaults.set(raw, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }

    /// Free-form taxon picked from the autocomplete. Session-only (not persisted).
    /// When set, takes precedence over `selected` for the effective taxon key.
    var taxonOverride: TaxonSuggestion? = nil

    /// The effective `taxonKey` to send to the GBIF API.
    /// Priority: explicit autocomplete pick → kingdom chip → nil (no filter).
    var effectiveTaxonKey: Int? {
        if let override = taxonOverride { return override.key }
        return selected?.taxonKey
    }

    /// Human label for the current effective filter, or nil when no filter is active.
    var effectiveLabel: String? {
        if let override = taxonOverride { return override.displayLabel }
        return selected?.displayLabel
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key) {
            self.selected = KingdomFilter(rawValue: raw)
        } else {
            self.selected = nil
        }
    }
}
