import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let vernacularLanguageKey = "vernacularLanguage"
    static let datasetsGlobalKey = "datasetsGlobal"
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.vernacularLanguage = defaults.string(forKey: Self.vernacularLanguageKey)
        self.datasetsGlobal = defaults.bool(forKey: Self.datasetsGlobalKey)
    }
}
