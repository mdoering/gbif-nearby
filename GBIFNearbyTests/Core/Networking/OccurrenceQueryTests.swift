import Testing
import Foundation
@testable import GBIFNearby

@Suite("OccurrenceQuery")
struct OccurrenceQueryTests {
    @Test("builds geo_distance + kingdom + facet params")
    func full() {
        var q = OccurrenceQuery()
        q.lat = 52.5200
        q.lng = 13.4050
        q.radiusKm = 5.0
        q.kingdomKey = 1
        q.facet = "speciesKey"
        q.facetLimit = 100
        q.facetMincount = 1
        q.limit = 0
        let items = q.queryItems()
        #expect(items.contains(URLQueryItem(name: "geo_distance", value: "52.5200,13.4050,5.0km")))
        #expect(items.contains(URLQueryItem(name: "kingdomKey", value: "1")))
        #expect(items.contains(URLQueryItem(name: "facet", value: "speciesKey")))
        #expect(items.contains(URLQueryItem(name: "facetLimit", value: "100")))
        #expect(items.contains(URLQueryItem(name: "facetMincount", value: "1")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "0")))
    }

    @Test("omits geo_distance when lat/lng/radius missing")
    func noGeo() {
        var q = OccurrenceQuery()
        q.limit = 20
        let items = q.queryItems()
        #expect(items.contains { $0.name == "geo_distance" } == false)
    }

    @Test("includes mediaType and hasCoordinate")
    func mediaAndCoord() {
        var q = OccurrenceQuery()
        q.mediaType = "StillImage"
        q.hasCoordinate = true
        let items = q.queryItems()
        #expect(items.contains(URLQueryItem(name: "mediaType", value: "StillImage")))
        #expect(items.contains(URLQueryItem(name: "hasCoordinate", value: "true")))
    }

    @Test("includes datasetKey and speciesKey filters")
    func focusKeys() {
        var q = OccurrenceQuery()
        q.datasetKey = "abc-123"
        q.speciesKey = 42
        let items = q.queryItems()
        #expect(items.contains(URLQueryItem(name: "datasetKey", value: "abc-123")))
        #expect(items.contains(URLQueryItem(name: "speciesKey", value: "42")))
    }
}
