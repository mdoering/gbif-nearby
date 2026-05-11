import Testing
import Foundation
@testable import GBIFNearby

@Suite("ImageCacheURL")
struct ImageCacheURLTests {
    @Test("width-only size")
    func widthOnly() {
        let url = ImageCacheURL.build(occurrenceKey: 12345,
                                      identifier: "https://example.org/img.jpg",
                                      size: .width(400))
        #expect(url.absoluteString.hasPrefix("https://api.gbif.org/v1/image/cache/400x/occurrence/12345/media/"))
        let tail = url.absoluteString.replacingOccurrences(of: "https://api.gbif.org/v1/image/cache/400x/occurrence/12345/media/", with: "")
        #expect(tail.count == 32)
        #expect(tail.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test("square size")
    func square() {
        let url = ImageCacheURL.build(occurrenceKey: 1,
                                      identifier: "x",
                                      size: .square(100))
        #expect(url.absoluteString.hasPrefix("https://api.gbif.org/v1/image/cache/100x100/occurrence/1/media/"))
    }

    @Test("md5 matches known reference")
    func md5Reference() {
        // md5("hello") = 5d41402abc4b2a76b9719d911017c592
        let url = ImageCacheURL.build(occurrenceKey: 7,
                                      identifier: "hello",
                                      size: .width(200))
        #expect(url.absoluteString == "https://api.gbif.org/v1/image/cache/200x/occurrence/7/media/5d41402abc4b2a76b9719d911017c592")
    }
}
