import Foundation
import Observation

@MainActor
@Observable
final class TaxonFilterStore {
    static let key = "kingdomFilter"
    private let defaults: UserDefaults

    var selected: KingdomFilter {
        didSet { defaults.set(selected.rawValue, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key), let value = KingdomFilter(rawValue: raw) {
            self.selected = value
        } else {
            self.selected = .all
        }
    }
}
