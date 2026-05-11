import Testing
import Foundation
@testable import GBIFNearby

@MainActor
@Suite("SettingsStore")
struct SettingsStoreTests {
    private func make() -> (SettingsStore, UserDefaults) {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (SettingsStore(defaults: suite), suite)
    }

    @Test("vernacularLanguage default is nil")
    func defaultValue() {
        let (s, _) = make()
        #expect(s.vernacularLanguage == nil)
    }

    @Test("persists when set")
    func persists() {
        let (s, d) = make()
        s.vernacularLanguage = "de"
        #expect(d.string(forKey: "vernacularLanguage") == "de")
    }

    @Test("setting empty string clears")
    func clearsOnEmpty() {
        let (s, d) = make()
        s.vernacularLanguage = "de"
        s.vernacularLanguage = ""
        #expect(s.vernacularLanguage == nil)
        #expect(d.string(forKey: "vernacularLanguage") == nil)
    }

    @Test("restores from defaults")
    func restores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("fr", forKey: "vernacularLanguage")
        let s = SettingsStore(defaults: suite)
        #expect(s.vernacularLanguage == "fr")
    }

    @Test("distanceUnit default derives from locale measurement system")
    func distanceUnitDefault() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let s = SettingsStore(defaults: suite)
        #expect(DistanceUnit.allCases.contains(s.distanceUnit))
    }

    @Test("distanceUnit persists when set")
    func distanceUnitPersists() {
        let (s, d) = make()
        s.distanceUnit = .miles
        #expect(d.string(forKey: "distanceUnit") == "miles")
        s.distanceUnit = .kilometers
        #expect(d.string(forKey: "distanceUnit") == "kilometers")
    }

    @Test("distanceUnit restores from defaults")
    func distanceUnitRestores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("miles", forKey: "distanceUnit")
        let s = SettingsStore(defaults: suite)
        #expect(s.distanceUnit == .miles)
    }
}
