import Foundation

enum DistanceFormatter {
    static func format(km: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .kilometers:
            return String(format: "%.1f km", km)
        case .miles:
            return String(format: "%.1f mi", km * 0.621371)
        }
    }
}
