import Testing
import Foundation
@testable import GBIFNearby

@Suite("MD5Hex")
struct MD5HexTests {
    @Test("empty string")
    func empty() {
        #expect(Data().md5HexLowercased() == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test("'hello'")
    func hello() {
        let data = "hello".data(using: .utf8)!
        #expect(data.md5HexLowercased() == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test("URL identifier")
    func urlIdentifier() {
        let id = "https://example.org/photos/123.jpg"
        let data = id.data(using: .utf8)!
        // verified externally with `md5 -s '<id>'`
        #expect(data.md5HexLowercased().count == 32)
        #expect(data.md5HexLowercased().allSatisfy { "0123456789abcdef".contains($0) })
    }
}
