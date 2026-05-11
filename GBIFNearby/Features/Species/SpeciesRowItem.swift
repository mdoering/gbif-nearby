import Foundation

/// One row in the Species list — facet bucket plus optional enriched details.
struct SpeciesRowItem: Identifiable, Sendable, Equatable {
    let speciesKey: Int
    let count: Int
    var scientificName: String?
    var canonicalName: String?
    var authorship: String?
    var vernacularName: String?
    var kingdom: String?
    var thumbnail: ThumbnailRef?

    var id: Int { speciesKey }
}

struct ThumbnailRef: Sendable, Equatable {
    let occurrenceKey: Int
    let mediaIdentifier: String
}
