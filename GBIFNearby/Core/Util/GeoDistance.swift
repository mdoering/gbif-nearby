import Foundation

enum GeoDistance {
    static func queryValue(lat: Double, lng: Double, radiusKm: Double) -> String {
        let latS = String(format: "%.4f", lat)
        let lngS = String(format: "%.4f", lng)
        let kmS = String(format: "%.1f", radiusKm)
        return "\(latS),\(lngS),\(kmS)km"
    }
}
