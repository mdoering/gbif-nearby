import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationStore: NSObject {
    enum Source { case device, manual }
    var current: CLLocationCoordinate2D?
    var source: Source = .device
    var authStatus: CLAuthorizationStatus = .notDetermined
    var lastError: Error?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Suppress per-second GPS jitter on a stationary device — without this,
        // every data tab refetches once a second and flashes its shimmer placeholder.
        manager.distanceFilter = 25
        authStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func setManual(_ coord: CLLocationCoordinate2D) {
        source = .manual
        current = coord
        manager.stopUpdatingLocation()
    }

    func clearManual() {
        source = .device
        startUpdating()
    }
}

extension LocationStore: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            startUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard source == .device, let loc = locations.last else { return }
        // Drop invalid / degraded fixes. CoreLocation's distanceFilter compares
        // *reported* coords; a 200 m-accuracy fix that jitters by 30 m every
        // second is enough to defeat the OS-level filter and reintroduce the
        // per-second refetch storm we're trying to avoid.
        if loc.horizontalAccuracy <= 0 || loc.horizontalAccuracy > 200 { return }
        // Software-level distance gate against the last published coordinate.
        // Mirrors what distanceFilter is meant to enforce, but stays correct
        // even when the OS delivers an update that crossed the threshold
        // through noise rather than real motion.
        if let prev = current {
            let prevCL = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            if loc.distance(from: prevCL) < 25 { return }
        }
        current = loc.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
    }
}
