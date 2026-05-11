import Testing
import Foundation
@testable import GBIFNearby

@Suite("DistanceFormatter")
struct DistanceFormatterTests {
    @Test("kilometers passes through with 1 decimal + km suffix")
    func km() {
        #expect(DistanceFormatter.format(km: 5.0, unit: .kilometers) == "5.0 km")
        #expect(DistanceFormatter.format(km: 0.1, unit: .kilometers) == "0.1 km")
        #expect(DistanceFormatter.format(km: 12.34, unit: .kilometers) == "12.3 km")
    }

    @Test("miles converts via 0.621371 with 1 decimal + mi suffix")
    func miles() {
        #expect(DistanceFormatter.format(km: 5.0, unit: .miles) == "3.1 mi")
        #expect(DistanceFormatter.format(km: 1.0, unit: .miles) == "0.6 mi")
        #expect(DistanceFormatter.format(km: 100.0, unit: .miles) == "62.1 mi")
    }

    @Test("zero radius renders 0.0 in both units")
    func zero() {
        #expect(DistanceFormatter.format(km: 0, unit: .kilometers) == "0.0 km")
        #expect(DistanceFormatter.format(km: 0, unit: .miles) == "0.0 mi")
    }
}
