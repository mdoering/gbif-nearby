import Testing
import Foundation
@testable import GBIFNearby

@Suite("Models")
struct ModelsTests {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private func fixture(_ name: String) throws -> Data {
        let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")!
        return try Data(contentsOf: url)
    }

    @Test("decodes /occurrence/search page")
    func decodesOccurrencePage() throws {
        let data = try fixture("occurrence-search")
        let page = try Self.decoder.decode(Page<Occurrence>.self, from: data)
        #expect(page.results.count <= 2)
        #expect(page.endOfRecords != nil)
    }

    @Test("decodes facet response")
    func decodesFacetResponse() throws {
        let data = try fixture("occurrence-facet-species")
        let page = try Self.decoder.decode(Page<Occurrence>.self, from: data)
        let field = page.facets?.first?.field
        #expect(field == "SPECIES_KEY" || field == "speciesKey")
    }

    @Test("KingdomFilter taxon-key mapping")
    func kingdomMapping() {
        #expect(KingdomFilter.all.taxonKey == nil)
        #expect(KingdomFilter.animals.taxonKey == 1)
        #expect(KingdomFilter.plants.taxonKey == 6)
        #expect(KingdomFilter.fungi.taxonKey == 5)
    }
}

final class BundleToken {}
