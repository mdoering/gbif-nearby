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

    private func freshSettings() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test("refreshVicinity facets occurrence search, enriches top buckets")
    func refreshVicinity() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.taxonKey == 6)
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

        let vm = DatasetsViewModel(client: fake, settings: freshSettings())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, taxonKey: 6, searchText: "")

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
        let vm = DatasetsViewModel(client: fake, settings: freshSettings())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, taxonKey: nil, searchText: "")
        if case .failed = vm.rows {} else { Issue.record("expected failed") }
    }

    @Test("global mode hits /dataset/search and maps to rows")
    func global() async {
        let fake = FakeGBIFClient()
        await fake.setDatasetSearch { query, page in
            #expect(query == "iNaturalist")
            #expect(page == 0)
            let ds = self.sampleDataset(key: "abc", title: "iNaturalist Research-grade")
            return Page(offset: 0, limit: 20, endOfRecords: true, count: 1,
                        results: [ds], facets: nil)
        }
        let settings = freshSettings()
        settings.datasetsGlobal = true
        let vm = DatasetsViewModel(client: fake, settings: settings)
        await vm.refresh(at: nil, radiusKm: 5, taxonKey: nil, searchText: "iNaturalist")
        switch vm.rows {
        case .loaded(let items):
            #expect(items.count == 1)
            #expect(items[0].key == "abc")
            #expect(items[0].title == "iNaturalist Research-grade")
            #expect(items[0].nearbyCount == nil)
        default: Issue.record("expected loaded, got \(vm.rows)")
        }
    }

    @Test("global mode with empty query passes nil to API")
    func globalEmptyQuery() async {
        let fake = FakeGBIFClient()
        await fake.setDatasetSearch { query, _ in
            #expect(query == nil || query == "")
            return Page(offset: 0, limit: 20, endOfRecords: true, count: 0, results: [], facets: nil)
        }
        let settings = freshSettings()
        settings.datasetsGlobal = true
        let vm = DatasetsViewModel(client: fake, settings: settings)
        await vm.refresh(at: nil, radiusKm: 5, taxonKey: nil, searchText: "")
        switch vm.rows {
        case .loaded(let items): #expect(items.isEmpty)
        default: Issue.record("expected loaded")
        }
    }

    @Test("vicinity search filters enriched rows by title (case-insensitive)")
    func vicinitySearchFilter() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "DATASET_KEY",
                                     counts: [self.bucket("a", 5), self.bucket("b", 3)])])
        }
        await fake.setDataset { key in
            self.sampleDataset(key: key, title: key == "a" ? "Birds of Berlin" : "Plants of Madrid")
        }
        let vm = DatasetsViewModel(client: fake, settings: freshSettings())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, taxonKey: nil, searchText: "BERLIN")
        guard case .loaded(let items) = vm.rows else { Issue.record("expected loaded"); return }
        #expect(items.count == 1)
        #expect(items[0].key == "a")
    }
}
