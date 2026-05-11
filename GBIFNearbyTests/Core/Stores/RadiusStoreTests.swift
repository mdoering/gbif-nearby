import Testing
import Foundation
@testable import GBIFNearby

@MainActor
@Suite("RadiusStore")
struct RadiusStoreTests {
    private func make() -> (RadiusStore, UserDefaults) {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (RadiusStore(defaults: suite), suite)
    }

    @Test("default is 2.5 km")
    func defaultValue() {
        let (store, _) = make()
        #expect(store.radiusKm == 2.5)
    }

    @Test("clamps to 0.1...100")
    func clamps() {
        let (store, _) = make()
        store.radiusKm = 0.01
        #expect(store.radiusKm == 0.1)
        store.radiusKm = 250
        #expect(store.radiusKm == 100)
    }

    @Test("persists to UserDefaults")
    func persists() {
        let (store, defaults) = make()
        store.radiusKm = 12.3
        #expect(defaults.double(forKey: "radiusKm") == 12.3)
    }

    @Test("reads existing value")
    func reads() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set(42.0, forKey: "radiusKm")
        let store = RadiusStore(defaults: suite)
        #expect(store.radiusKm == 42.0)
    }
}
