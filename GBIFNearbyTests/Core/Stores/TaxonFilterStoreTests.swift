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

    @Test("default is .all")
    func defaultValue() {
        let (store, _) = make()
        #expect(store.selected == .all)
    }

    @Test("persists selection")
    func persists() {
        let (store, defaults) = make()
        store.selected = .plants
        #expect(defaults.string(forKey: "kingdomFilter") == "plants")
    }

    @Test("restores selection")
    func restores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("fungi", forKey: "kingdomFilter")
        let store = TaxonFilterStore(defaults: suite)
        #expect(store.selected == .fungi)
    }
}
