import Foundation
import Observation

enum Tab: String, CaseIterable, Sendable {
    case map, species, gallery, datasets, about
}

@MainActor
@Observable
final class TabSelectionStore {
    var current: Tab = .map
}
