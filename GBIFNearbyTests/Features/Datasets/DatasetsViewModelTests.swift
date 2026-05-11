import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("DatasetsViewModel — vicinity")
struct DatasetsViewModelTests {
    nonisolated private func bucket(_ key: String, _ count: Int) -> FacetBucket {
        FacetBucket(name: key, count: count)
    }

    nonisolated private func sampleDataset(key: String, title: String, publisher: String = "Org") -> Dataset {
        Dataset(key: key, title: title, type: "OCCURRENCE", license: "CC0_1_0",
                description: "Sample", publishingOrganizationKey: nil,
                publishingOrganizationTitle: publisher, citation: nil, contacts: nil)
    }

    @Test("refreshVicinity facets occurrence search, enriches top buckets")
    func refreshVicinity() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.kingdomKey == 6)
            #expect(q.facet == "datasetKey")
            #expect(q.facetLimit == 100)
            #expect(q.facetMincount == 1)
            #expect(q.limit == 0)
            return Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                        facets: [FacetGroup(field: "DATASET_KEY",
                                            counts: [self.bucket("ds-a", 50),
                                                     self.bucket("ds-b", 20)])])
        }
        await fake.setDataset { key in
            self.sampleDataset(key: key, title: "Dataset \(key)")
        }

        let vm = DatasetsViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, kingdomKey: 6, searchText: "")

        switch vm.rows {
        case .loaded(let items):
            #expect(items.count == 2)
            #expect(items[0].key == "ds-a")
            #expect(items[0].title == "Dataset ds-a")
            #expect(items[0].nearbyCount == 50)
        default: Issue.record("expected loaded, got \(vm.rows)")
        }
    }

    @Test("vicinity network error sets failed state")
    func vicinityError() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 500, message: nil) }
        let vm = DatasetsViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, searchText: "")
        if case .failed = vm.rows {} else { Issue.record("expected failed") }
    }
}
