import Foundation
import Observation

@MainActor
@Observable
final class RadiusStore {
    static let key = "radiusKm"
    static let minValue: Double = 0.1
    static let maxValue: Double = 100.0
    static let defaultValue: Double = 2.5

    private let defaults: UserDefaults

    var radiusKm: Double {
        didSet {
            let clamped = min(max(radiusKm, Self.minValue), Self.maxValue)
            if clamped != radiusKm {
                radiusKm = clamped
                return
            }
            defaults.set(radiusKm, forKey: Self.key)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Self.key)
        self.radiusKm = stored == 0 ? Self.defaultValue : stored
    }
}
