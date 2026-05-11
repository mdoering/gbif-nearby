import Testing
@testable import GBIFNearby

@Suite("GeoDistance")
struct GeoDistanceTests {
    @Test("formats lat,lng,Xkm with 4-decimal precision")
    func basic() {
        let s = GeoDistance.queryValue(lat: 52.5200, lng: 13.4050, radiusKm: 5.0)
        #expect(s == "52.5200,13.4050,5.0km")
    }

    @Test("preserves sub-km precision to 1 decimal")
    func subKm() {
        let s = GeoDistance.queryValue(lat: 0.0, lng: 0.0, radiusKm: 0.1)
        #expect(s == "0.0000,0.0000,0.1km")
    }

    @Test("rounds radius to 1 decimal")
    func roundsRadius() {
        let s = GeoDistance.queryValue(lat: 1.0, lng: 2.0, radiusKm: 7.84)
        #expect(s == "1.0000,2.0000,7.8km")
    }

    @Test("supports negative coordinates")
    func negative() {
        let s = GeoDistance.queryValue(lat: -33.8688, lng: 151.2093, radiusKm: 12.0)
        #expect(s == "-33.8688,151.2093,12.0km")
    }
}
