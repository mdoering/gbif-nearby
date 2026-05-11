import Foundation

struct GalleryTile: Identifiable, Sendable, Equatable {
    let occurrence: Occurrence
    let mediaIndex: Int
    let identifier: String

    var id: String { "\(occurrence.key)_\(mediaIndex)" }
    var displayName: String { occurrence.scientificName ?? occurrence.species ?? "#\(occurrence.key)" }
}
