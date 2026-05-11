import Testing
import Foundation
@testable import GBIFNearby

@MainActor
@Suite("TaxonFilterStore")
struct TaxonFilterStoreTests {
    private func make() -> (TaxonFilterStore, UserDefaults) {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (TaxonFilterStore(defaults: suite), suite)
    }

    @Test("default has no selection")
    func defaultValue() {
        let (store, _) = make()
        #expect(store.selected == nil)
        #expect(store.taxonOverride == nil)
        #expect(store.effectiveTaxonKey == nil)
        #expect(store.effectiveLabel == nil)
    }

    @Test("persists selection")
    func persists() {
        let (store, defaults) = make()
        store.selected = .plants
        #expect(defaults.string(forKey: "kingdomFilter") == "plants")
    }

    @Test("clearing selection removes UserDefaults entry")
    func clears() {
        let (store, defaults) = make()
        store.selected = .fungi
        store.selected = nil
        #expect(defaults.string(forKey: "kingdomFilter") == nil)
        #expect(store.effectiveTaxonKey == nil)
    }

    @Test("restores selection")
    func restores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("fungi", forKey: "kingdomFilter")
        let store = TaxonFilterStore(defaults: suite)
        #expect(store.selected == .fungi)
    }

    @Test("kingdom selection drives effectiveTaxonKey")
    func kingdomKey() {
        let (store, _) = make()
        store.selected = .animals
        #expect(store.effectiveTaxonKey == 1)
        #expect(store.effectiveLabel == "Animals")
    }

    @Test("taxonOverride wins over kingdom selection")
    func overrideWins() {
        let (store, _) = make()
        store.selected = .plants
        store.taxonOverride = TaxonSuggestion(key: 5231190, scientificName: "Bombus terrestris",
                                              canonicalName: "Bombus terrestris", rank: "SPECIES")
        #expect(store.effectiveTaxonKey == 5231190)
        #expect(store.effectiveLabel?.contains("Bombus terrestris") == true)
    }

    @Test("taxonOverride is session-only (not persisted)")
    func overrideNotPersisted() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let s1 = TaxonFilterStore(defaults: suite)
        s1.taxonOverride = TaxonSuggestion(key: 9, scientificName: "X", canonicalName: nil, rank: nil)
        let s2 = TaxonFilterStore(defaults: suite)
        #expect(s2.taxonOverride == nil)
    }
}
