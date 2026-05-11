import Foundation

/// One row in the Datasets list. Combines a (possibly partial) Dataset with an optional
/// "records nearby" facet count for vicinity-aware mode.
struct DatasetRowItem: Identifiable, Sendable, Equatable {
    let key: String
    var title: String?
    var publisher: String?
    var type: String?
    var license: String?
    var nearbyCount: Int?

    var id: String { key }
}
