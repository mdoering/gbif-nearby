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
        current = loc.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
    }
}
