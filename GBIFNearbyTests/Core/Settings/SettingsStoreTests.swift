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

    @Test("datasetsGlobal default is false")
    func datasetsGlobalDefault() {
        let (s, _) = make()
        #expect(s.datasetsGlobal == false)
    }

    @Test("datasetsGlobal persists when set")
    func datasetsGlobalPersists() {
        let (s, d) = make()
        s.datasetsGlobal = true
        #expect(d.bool(forKey: "datasetsGlobal") == true)
    }

    @Test("datasetsGlobal restores from defaults")
    func datasetsGlobalRestores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set(true, forKey: "datasetsGlobal")
        let s = SettingsStore(defaults: suite)
        #expect(s.datasetsGlobal == true)
    }
}
