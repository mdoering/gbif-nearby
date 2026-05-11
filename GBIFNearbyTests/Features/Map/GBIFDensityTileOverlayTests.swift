import Testing
import Foundation
import MapKit
@testable import GBIFNearby

@Suite("GBIFDensityTileOverlay")
struct GBIFDensityTileOverlayTests {
    @Test("base URL when no filters")
    func base() {
        let overlay = GBIFDensityTileOverlay(taxonKey: nil, datasetKey: nil)
        let url = overlay.url(forTilePath: .init(x: 1, y: 2, z: 3, contentScaleFactor: 1))
        let str = url.absoluteString
        #expect(str.contains("/v2/map/occurrence/density/3/1/2@1x.png"))
        #expect(str.contains("srs=EPSG:3857"))
        #expect(str.contains("style=classic.poly"))
        #expect(str.contains("bin=hex"))
        #expect(str.contains("hexPerTile=75"))
        #expect(str.contains("taxonKey=") == false)
        #expect(str.contains("datasetKey=") == false)
    }

    @Test("appends taxonKey when set")
    func taxonKey() {
        let overlay = GBIFDensityTileOverlay(taxonKey: 6, datasetKey: nil)
        let url = overlay.url(forTilePath: .init(x: 0, y: 0, z: 0, contentScaleFactor: 1))
        #expect(url.absoluteString.contains("taxonKey=6"))
    }

    @Test("appends datasetKey when set")
    func datasetKey() {
        let overlay = GBIFDensityTileOverlay(taxonKey: nil, datasetKey: "abc-123")
        let url = overlay.url(forTilePath: .init(x: 0, y: 0, z: 0, contentScaleFactor: 1))
        #expect(url.absoluteString.contains("datasetKey=abc-123"))
    }
}
