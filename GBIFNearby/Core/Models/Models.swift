import Foundation

struct Page<Element: Codable & Sendable>: Codable, Sendable {
    let offset: Int?
    let limit: Int?
    let endOfRecords: Bool?
    let count: Int?
    let results: [Element]
    let facets: [FacetGroup]?
}

struct FacetGroup: Codable, Sendable {
    let field: String
    let counts: [FacetBucket]
}

struct FacetBucket: Codable, Sendable {
    let name: String
    let count: Int
}

struct Occurrence: Codable, Sendable, Identifiable, Equatable {
    let key: Int
    let datasetKey: String?
    let speciesKey: Int?
    let species: String?
    let scientificName: String?
    let acceptedScientificName: String?
    let kingdom: String?
    let phylum: String?
    let `class`: String?
    let order: String?
    let family: String?
    let genus: String?
    let decimalLatitude: Double?
    let decimalLongitude: Double?
    let eventDate: String?
    let recordedBy: String?
    let basisOfRecord: String?
    let media: [Media]?

    var id: Int { key }
}

struct Media: Codable, Sendable, Equatable {
    let type: String?
    let format: String?
    let identifier: String?
    let title: String?
    let creator: String?
    let license: String?
}

struct Dataset: Codable, Sendable, Identifiable {
    let key: String
    let title: String
    let type: String?
    let license: String?
    let description: String?
    let publishingOrganizationKey: String?
    let publishingOrganizationTitle: String?
    let citation: Citation?
    let contacts: [DatasetContact]?

    var id: String { key }
}

struct Citation: Codable, Sendable {
    let text: String?
}

struct DatasetContact: Codable, Sendable {
    let firstName: String?
    let lastName: String?
    let email: [String]?
    let type: String?
}

struct Species: Codable, Sendable, Identifiable {
    let key: Int
    let scientificName: String?
    let canonicalName: String?
    let authorship: String?
    let kingdom: String?
    let phylum: String?
    let `class`: String?
    let order: String?
    let family: String?
    let genus: String?
    let rank: String?

    var id: Int { key }
}

struct VernacularName: Codable, Sendable {
    let vernacularName: String
    let language: String?
}

/// Lightweight result from `/species/suggest` — enough to drive the autocomplete and to
/// remember a selection.
struct TaxonSuggestion: Codable, Sendable, Identifiable, Hashable, Equatable {
    let key: Int
    let scientificName: String
    let canonicalName: String?
    let rank: String?

    var id: Int { key }

    /// Human-readable label for the chip / autocomplete row.
    /// Example: "Bombus terrestris (SPECIES)"
    var displayLabel: String {
        if let rank, rank.isEmpty == false {
            return "\(scientificName) (\(rank.lowercased()))"
        }
        return scientificName
    }
}
