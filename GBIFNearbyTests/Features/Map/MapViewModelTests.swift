import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("MapViewModel")
struct MapViewModelTests {
    @Test("fetchPins forwards geo_distance and kingdom + decodes pins")
    func fetchPins() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.taxonKey == 6)
            #expect(q.hasCoordinate == true)
            #expect(q.limit == 300)
            return Page(offset: 0, limit: 300, endOfRecords: true, count: 1,
                        results: [Occurrence(key: 99, datasetKey: nil, speciesKey: 7, species: "Bellis perennis",
                                             scientificName: "Bellis perennis", acceptedScientificName: nil,
                                             kingdom: "Plantae", phylum: nil, class: nil, order: nil, family: nil, genus: nil,
                                             decimalLatitude: 52.5001, decimalLongitude: 13.4001,
                                             eventDate: nil, recordedBy: nil, basisOfRecord: nil, media: nil)],
                        facets: nil)
        }
        let vm = MapViewModel(client: fake)
        await vm.fetchPins(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                           radiusKm: 5.0, taxonKey: 6, datasetKey: nil, speciesKey: nil)
        switch vm.pins {
        case .loaded(let arr): #expect(arr.count == 1); #expect(arr[0].key == 99)
        default: Issue.record("expected loaded state, got \(vm.pins)")
        }
        #expect(await fake.recordedSearches.count == 1)
    }

    @Test("on error sets failed state")
    func error() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 503, message: nil) }
        let vm = MapViewModel(client: fake)
        await vm.fetchPins(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                           radiusKm: 1.0, taxonKey: nil, datasetKey: nil, speciesKey: nil)
        if case .failed = vm.pins {} else {
            Issue.record("expected failed state")
        }
    }

    @Test("clearPins resets to idle")
    func clearPins() async {
        let vm = MapViewModel(client: FakeGBIFClient())
        vm.clearPins()
        if case .idle = vm.pins {} else {
            Issue.record("expected idle")
        }
    }
}
