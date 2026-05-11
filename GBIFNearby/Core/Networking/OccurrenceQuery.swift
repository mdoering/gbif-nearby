import Foundation

struct OccurrenceQuery: Sendable, Equatable {
    var lat: Double?
    var lng: Double?
    var radiusKm: Double?
    /// Filters by any GBIF taxon key (kingdom, phylum, … species). Kingdom keys
    /// (Animalia 1, Fungi 5, Plantae 6) are valid taxonKey values, so we no longer
    /// expose a separate `kingdomKey`.
    var taxonKey: Int?
    var datasetKey: String?
    var speciesKey: Int?
    var mediaType: String?
    var hasCoordinate: Bool?
    var facet: String?
    var facetLimit: Int?
    var facetMincount: Int?
    var limit: Int?
    var offset: Int?

    func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let lat, let lng, let radiusKm {
            items.append(.init(name: "geo_distance", value: GeoDistance.queryValue(lat: lat, lng: lng, radiusKm: radiusKm)))
        }
        if let taxonKey { items.append(.init(name: "taxonKey", value: String(taxonKey))) }
        if let datasetKey { items.append(.init(name: "datasetKey", value: datasetKey)) }
        if let speciesKey { items.append(.init(name: "speciesKey", value: String(speciesKey))) }
        if let mediaType { items.append(.init(name: "mediaType", value: mediaType)) }
        if let hasCoordinate { items.append(.init(name: "hasCoordinate", value: hasCoordinate ? "true" : "false")) }
        if let facet { items.append(.init(name: "facet", value: facet)) }
        if let facetLimit { items.append(.init(name: "facetLimit", value: String(facetLimit))) }
        if let facetMincount { items.append(.init(name: "facetMincount", value: String(facetMincount))) }
        if let limit { items.append(.init(name: "limit", value: String(limit))) }
        if let offset { items.append(.init(name: "offset", value: String(offset))) }
        return items
    }
}
