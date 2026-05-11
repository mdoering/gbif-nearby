import Foundation
import Observation

@MainActor
@Observable
final class FocusFilterStore {
    var datasetKey: String?
    var speciesKey: Int?
    var label: String?

    var isActive: Bool { datasetKey != nil || speciesKey != nil }

    func set(datasetKey: String, label: String) {
        self.datasetKey = datasetKey
        self.speciesKey = nil
        self.label = label
    }

    func set(speciesKey: Int, label: String) {
        self.speciesKey = speciesKey
        self.datasetKey = nil
        self.label = label
    }

    func clear() {
        datasetKey = nil
        speciesKey = nil
        label = nil
    }
}
