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

    nonisolated private func sampleDataset(key: String, title: String,
                                           publisher: String? = "Org",
                                           publisherKey: String? = nil) -> Dataset {
        Dataset(key: key, title: title, type: "OCCURRENCE", license: "CC0_1_0",
                description: "Sample", doi: "10.0/test", publishingOrganizationKey: publisherKey,
                publishingOrganizationTitle: publisher, citation: nil, contacts: nil)
    }

    @Test("refresh facets occurrence search, enriches top buckets")
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

        let vm = DatasetsViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, taxonKey: 6)

        switch vm.rows {
        case .loaded(let items):
            #expect(items.count == 2)
            #expect(items[0].key == "ds-a")
            #expect(items[0].title == "Dataset ds-a")
            #expect(items[0].publisher == "Org")
            #expect(items[0].nearbyCount == 50)
        default: Issue.record("expected loaded, got \(vm.rows)")
        }
    }

    @Test("network error sets failed state")
    func vicinityError() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 500, message: nil) }
        let vm = DatasetsViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, taxonKey: nil)
        if case .failed = vm.rows {} else { Issue.record("expected failed") }
    }

    @Test("nil location resolves to an empty list, no network calls")
    func nilLocation() async {
        let fake = FakeGBIFClient()
        let vm = DatasetsViewModel(client: fake)
        await vm.refresh(at: nil, radiusKm: 5, taxonKey: nil)
        switch vm.rows {
        case .loaded(let items): #expect(items.isEmpty)
        default: Issue.record("expected loaded empty")
        }
        let recorded = await fake.recordedSearches
        #expect(recorded.isEmpty)
    }

    @Test("missing publisher title falls back to /organization/{key}")
    func publisherFallback() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "DATASET_KEY", counts: [self.bucket("ds", 5)])])
        }
        await fake.setDataset { _ in
            self.sampleDataset(key: "ds", title: "EOD", publisher: nil, publisherKey: "org-key")
        }
        await fake.setOrganization { key in
            #expect(key == "org-key")
            return Organization(key: key, title: "Cornell Lab of Ornithology")
        }
        let vm = DatasetsViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, taxonKey: nil)
        guard case .loaded(let items) = vm.rows else { Issue.record("expected loaded"); return }
        #expect(items[0].publisher == "Cornell Lab of Ornithology")
    }

    @Test("present publisher title skips the /organization fallback")
    func publisherNoFallback() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "DATASET_KEY", counts: [self.bucket("ds", 5)])])
        }
        await fake.setDataset { _ in
            self.sampleDataset(key: "ds", title: "Title", publisher: "iNaturalist.org", publisherKey: "ok")
        }
        let vm = DatasetsViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, taxonKey: nil)
        let orgCalls = await fake.recordedOrganizationKeys
        #expect(orgCalls.isEmpty)
    }
}
