import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("SpeciesViewModel — facet")
struct SpeciesViewModelTests {
    private nonisolated func bucket(_ key: String, _ count: Int) -> FacetBucket {
        FacetBucket(name: key, count: count)
    }

    @Test("refresh forwards geo_distance + kingdom + facet params, decodes rows")
    func refresh() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.kingdomKey == 6)
            #expect(q.facet == "speciesKey")
            #expect(q.facetLimit == 100)
            #expect(q.facetMincount == 1)
            #expect(q.limit == 0)
            return Page(offset: 0, limit: 0, endOfRecords: true, count: 12,
                        results: [],
                        facets: [FacetGroup(field: "SPECIES_KEY",
                                            counts: [self.bucket("5231190", 42),
                                                     self.bucket("5219404", 13)])])
        }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, kingdomKey: 6, datasetKey: nil, speciesKey: nil)
        switch vm.rows {
        case .loaded(let items):
            #expect(items.count == 2)
            #expect(items[0].speciesKey == 5231190)
            #expect(items[0].count == 42)
            #expect(items[1].speciesKey == 5219404)
            #expect(items[1].count == 13)
        default: Issue.record("expected loaded, got \(vm.rows)")
        }
    }

    @Test("network error sets failed state")
    func error() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 502, message: nil) }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1.0, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        if case .failed = vm.rows {} else { Issue.record("expected failed") }
    }

    @Test("empty facet returns loaded empty list (not failed)")
    func empty() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0,
                 results: [], facets: [FacetGroup(field: "SPECIES_KEY", counts: [])])
        }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1.0, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        switch vm.rows {
        case .loaded(let items): #expect(items.isEmpty)
        default: Issue.record("expected loaded empty")
        }
    }

    nonisolated private func sampleSpecies(key: Int, sci: String, kingdom: String = "Plantae") -> Species {
        Species(key: key, scientificName: sci, canonicalName: sci, authorship: "L., 1758",
                kingdom: kingdom, phylum: nil, class: nil, order: nil, family: nil,
                genus: nil, rank: "SPECIES")
    }

    @Test("enrichTopRows fills scientific + vernacular + kingdom")
    func enrich() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "SPECIES_KEY",
                                     counts: [self.bucket("1", 5), self.bucket("2", 3)])])
        }
        await fake.setSpecies { key in
            self.sampleSpecies(key: key, sci: "Species \(key)")
        }
        await fake.setVernacular { key, lang in
            #expect(lang == "de")
            return [VernacularName(vernacularName: "Art \(key)", language: "de")]
        }

        let settings = SettingsStore()
        settings.vernacularLanguage = "de"
        let vm = SpeciesViewModel(client: fake, settings: settings)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        await vm.enrichTopRows(limit: 30)

        guard case .loaded(let items) = vm.rows else {
            Issue.record("expected loaded"); return
        }
        #expect(items.count == 2)
        #expect(items[0].scientificName == "Species 1")
        #expect(items[0].vernacularName == "Art 1")
        #expect(items[0].kingdom == "Plantae")
    }

    @Test("vernacular falls back to English when locale miss")
    func vernacularFallback() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "SPECIES_KEY", counts: [self.bucket("1", 5)])])
        }
        await fake.setSpecies { key in self.sampleSpecies(key: key, sci: "Sp \(key)") }
        await fake.setVernacular { _, lang in
            if lang == "en" { return [VernacularName(vernacularName: "Daisy", language: "en")] }
            return []
        }
        let settings = SettingsStore()
        settings.vernacularLanguage = "fr"
        let vm = SpeciesViewModel(client: fake, settings: settings)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        await vm.enrichTopRows(limit: 30)

        guard case .loaded(let items) = vm.rows else { Issue.record("expected loaded"); return }
        #expect(items[0].vernacularName == "Daisy")
    }

    @Test("fetchThumbnails populates ThumbnailRef from /occurrence/search?speciesKey=...&mediaType=StillImage")
    func thumbnails() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            if q.speciesKey == 1, q.mediaType == "StillImage", q.limit == 1 {
                let occ = Occurrence(key: 9001, datasetKey: nil, speciesKey: 1, species: nil,
                                     scientificName: nil, acceptedScientificName: nil,
                                     kingdom: nil, phylum: nil, class: nil, order: nil, family: nil, genus: nil,
                                     decimalLatitude: nil, decimalLongitude: nil,
                                     eventDate: nil, recordedBy: nil, basisOfRecord: nil,
                                     media: [Media(type: "StillImage", format: nil,
                                                   identifier: "https://example.org/img.jpg",
                                                   title: nil, creator: nil, license: nil)])
                return Page(offset: 0, limit: 1, endOfRecords: true, count: 1, results: [occ], facets: nil)
            }
            return Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                        facets: [FacetGroup(field: "SPECIES_KEY", counts: [self.bucket("1", 5)])])
        }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        await vm.fetchThumbnails(limit: 30)

        guard case .loaded(let items) = vm.rows else { Issue.record("expected loaded"); return }
        #expect(items[0].thumbnail?.occurrenceKey == 9001)
        #expect(items[0].thumbnail?.mediaIdentifier == "https://example.org/img.jpg")
    }
}
