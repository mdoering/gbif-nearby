import Testing
@testable import GBIFNearby

@Suite("Smoke")
struct SmokeTest {
    @Test("Module imports")
    func moduleImports() {
        // If this compiles, the test target is wired correctly.
        #expect(Bool(true))
    }
}
