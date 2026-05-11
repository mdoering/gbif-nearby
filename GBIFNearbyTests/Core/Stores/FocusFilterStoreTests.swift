import Testing
@testable import GBIFNearby

@MainActor
@Suite("FocusFilterStore")
struct FocusFilterStoreTests {
    @Test("starts empty")
    func empty() {
        let store = FocusFilterStore()
        #expect(store.datasetKey == nil)
        #expect(store.speciesKey == nil)
        #expect(store.isActive == false)
    }

    @Test("setting datasetKey activates filter")
    func dataset() {
        let store = FocusFilterStore()
        store.set(datasetKey: "abc-123", label: "Sample Dataset")
        #expect(store.datasetKey == "abc-123")
        #expect(store.label == "Sample Dataset")
        #expect(store.isActive == true)
    }

    @Test("clear resets everything")
    func clear() {
        let store = FocusFilterStore()
        store.set(speciesKey: 7, label: "Some species")
        store.clear()
        #expect(store.datasetKey == nil)
        #expect(store.speciesKey == nil)
        #expect(store.label == nil)
        #expect(store.isActive == false)
    }
}
