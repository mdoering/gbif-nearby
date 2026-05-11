import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let vernacularLanguageKey = "vernacularLanguage"
    static let datasetsGlobalKey = "datasetsGlobal"
    static let distanceUnitKey = "distanceUnit"
    private let defaults: UserDefaults

    var vernacularLanguage: String? {
        didSet {
            // Filter empty strings to nil
            if let v = vernacularLanguage, v.isEmpty {
                vernacularLanguage = nil
            }
            // Persist to UserDefaults
            if let v = vernacularLanguage {
                defaults.set(v, forKey: Self.vernacularLanguageKey)
            } else {
                defaults.removeObject(forKey: Self.vernacularLanguageKey)
            }
        }
    }

    var datasetsGlobal: Bool {
        didSet {
            defaults.set(datasetsGlobal, forKey: Self.datasetsGlobalKey)
        }
    }

    var distanceUnit: DistanceUnit {
        didSet {
            defaults.set(distanceUnit.rawValue, forKey: Self.distanceUnitKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.vernacularLanguage = defaults.string(forKey: Self.vernacularLanguageKey)
        self.datasetsGlobal = defaults.bool(forKey: Self.datasetsGlobalKey)
        if let raw = defaults.string(forKey: Self.distanceUnitKey),
           let value = DistanceUnit(rawValue: raw) {
            self.distanceUnit = value
        } else {
            self.distanceUnit = DistanceUnit.fromLocale()
        }
    }
}
