import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("GalleryViewModel — refresh")
struct GalleryViewModelTests {
    nonisolated private func occurrence(key: Int, mediaIds: [String], species: String = "X") -> Occurrence {
        Occurrence(
            key: key, datasetKey: nil, speciesKey: nil, species: species,
            scientificName: species, acceptedScientificName: nil,
            kingdom: nil, phylum: nil, class: nil, order: nil, family: nil, genus: nil,
            decimalLatitude: 52.5, decimalLongitude: 13.4,
            eventDate: nil, recordedBy: nil, basisOfRecord: nil,
            media: mediaIds.map { Media(type: "StillImage", format: nil, identifier: $0,
                                        title: nil, creator: nil, license: nil) }
        )
    }

    @Test("refresh forwards filters and flattens media into tiles")
    func refresh() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.kingdomKey == 1)
            #expect(q.mediaType == "StillImage")
            #expect(q.hasCoordinate == true)
            #expect(q.limit == 50)
            #expect(q.offset == 0)
            return Page(offset: 0, limit: 50, endOfRecords: false, count: 100,
                        results: [
                            self.occurrence(key: 1, mediaIds: ["a", "b"], species: "Bombus"),
                            self.occurrence(key: 2, mediaIds: ["c"], species: "Apis"),
                            self.occurrence(key: 3, mediaIds: [], species: "Mantis"),
                        ],
                        facets: nil)
        }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, kingdomKey: 1, datasetKey: nil, speciesKey: nil)
        switch vm.tiles {
        case .loaded(let arr):
            #expect(arr.count == 3)
            #expect(arr[0].occurrence.key == 1)
            #expect(arr[0].mediaIndex == 0)
            #expect(arr[0].identifier == "a")
            #expect(arr[1].occurrence.key == 1)
            #expect(arr[1].mediaIndex == 1)
            #expect(arr[2].occurrence.key == 2)
        default: Issue.record("expected loaded, got \(vm.tiles)")
        }
        #expect(vm.endOfResults == false)
    }

    @Test("skips occurrences with no still-image media; sets endOfResults from page flag")
    func endOfResults() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 50, endOfRecords: true, count: 0,
                 results: [self.occurrence(key: 9, mediaIds: [])],
                 facets: nil)
        }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        switch vm.tiles {
        case .loaded(let arr): #expect(arr.isEmpty)
        default: Issue.record("expected loaded empty")
        }
        #expect(vm.endOfResults == true)
    }

    @Test("network error sets failed state")
    func error() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 500, message: nil) }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        if case .failed = vm.tiles {} else { Issue.record("expected failed") }
    }
}
