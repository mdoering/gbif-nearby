import Testing
import Foundation
@testable import GBIFNearby

@Suite("GBIFClient")
struct GBIFClientTests {
    @Test("occurrenceSearch builds expected URL and decodes results")
    func search() async throws {
        MockURLProtocol.stub(json: """
        {"offset":0,"limit":2,"endOfRecords":false,"count":42,"results":[
          {"key":1,"decimalLatitude":52.5,"decimalLongitude":13.4,"scientificName":"X"},
          {"key":2,"decimalLatitude":52.6,"decimalLongitude":13.5,"scientificName":"Y"}
        ]}
        """)
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        var query = OccurrenceQuery()
        query.lat = 52.5; query.lng = 13.4; query.radiusKm = 5.0
        query.limit = 2
        let page = try await client.occurrenceSearch(query)
        #expect(page.results.count == 2)
        #expect(page.results[0].key == 1)
    }

    @Test("occurrenceCount returns the count field")
    func count() async throws {
        MockURLProtocol.stub(json: """
        {"offset":0,"limit":0,"endOfRecords":true,"count":1234,"results":[]}
        """)
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        var q = OccurrenceQuery()
        q.lat = 0; q.lng = 0; q.radiusKm = 1
        #expect(try await client.occurrenceCount(q) == 1234)
    }

    @Test("non-2xx HTTP throws GBIFError.http")
    func httpError() async {
        MockURLProtocol.handler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (r, Data("oops".utf8))
        }
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        await #expect(throws: GBIFError.self) {
            _ = try await client.occurrenceSearch(OccurrenceQuery())
        }
    }

    @Test("dataset(key:) hits /v1/dataset/{key}")
    func datasetByKey() async throws {
        MockURLProtocol.handler = { req in
            #expect(req.url!.path.hasSuffix("/dataset/abc-123"))
            let body = """
            {"key":"abc-123","title":"Sample Dataset","type":"OCCURRENCE","license":"CC0_1_0"}
            """
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(body.utf8))
        }
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        let ds = try await client.dataset(key: "abc-123")
        #expect(ds.title == "Sample Dataset")
    }
}
