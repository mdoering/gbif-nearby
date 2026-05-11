import Foundation
import MapKit

final class GBIFDensityTileOverlay: MKTileOverlay {
    let taxonKey: Int?
    let datasetKey: String?
    let speciesKey: Int?

    init(taxonKey: Int?, datasetKey: String?, speciesKey: Int? = nil) {
        self.taxonKey = taxonKey
        self.datasetKey = datasetKey
        self.speciesKey = speciesKey
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = 0
        self.maximumZ = 18
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        var comps = URLComponents(string: "https://api.gbif.org/v2/map/occurrence/density/\(path.z)/\(path.x)/\(path.y)@1x.png")!
        var items: [URLQueryItem] = [
            .init(name: "srs", value: "EPSG:3857"),
            .init(name: "style", value: "classic.poly"),
            .init(name: "bin", value: "hex"),
            .init(name: "hexPerTile", value: "75"),
        ]
        if let taxonKey { items.append(.init(name: "taxonKey", value: String(taxonKey))) }
        if let datasetKey { items.append(.init(name: "datasetKey", value: datasetKey)) }
        if let speciesKey { items.append(.init(name: "speciesKey", value: String(speciesKey))) }
        comps.queryItems = items
        return comps.url!
    }
}
