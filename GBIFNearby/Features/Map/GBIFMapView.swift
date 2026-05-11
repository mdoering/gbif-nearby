import SwiftUI
import MapKit

struct GBIFMapView: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var radiusKm: Double
    var taxonKey: Int?
    var datasetKey: String?
    var speciesKey: Int?
    var pins: [Occurrence]
    var mapType: MKMapType = .standard
    var recenterID: Int = 0
    var onPinTap: (Occurrence) -> Void
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var onRegionChange: ((MKCoordinateRegion) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        let lp = UILongPressGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.longPress(_:)))
        lp.minimumPressDuration = 0.6
        map.addGestureRecognizer(lp)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        if map.mapType != mapType { map.mapType = mapType }
        context.coordinator.applyRegion(map)
        context.coordinator.applyCircle(map)
        context.coordinator.applyTileOverlay(map)
        context.coordinator.applyPins(map)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GBIFMapView
        private var currentOverlayKey: String?
        private var currentCenter: CLLocationCoordinate2D?
        private var currentRadius: Double?
        private var currentRecenterID: Int = -1

        init(_ parent: GBIFMapView) {
            self.parent = parent
        }

        func applyRegion(_ map: MKMapView) {
            // Recenter on first appearance, on center/radius change, or when recenterID bumps.
            let c = parent.center
            let centerChanged = currentCenter == nil || !same(currentCenter!, c)
            let radiusChanged = currentRadius != parent.radiusKm
            let recenterRequested = currentRecenterID != parent.recenterID
            if centerChanged || radiusChanged || recenterRequested {
                let span = max(parent.radiusKm, 0.5) * 3000 // meters, ~3x diameter
                let region = MKCoordinateRegion(center: c, latitudinalMeters: span, longitudinalMeters: span)
                map.setRegion(region, animated: currentCenter != nil)
                currentCenter = c
                currentRadius = parent.radiusKm
                currentRecenterID = parent.recenterID
            }
        }

        func applyCircle(_ map: MKMapView) {
            map.overlays
                .compactMap { $0 as? MKCircle }
                .forEach(map.removeOverlay)
            let circle = MKCircle(center: parent.center, radius: parent.radiusKm * 1000)
            map.addOverlay(circle, level: .aboveRoads)
        }

        func applyTileOverlay(_ map: MKMapView) {
            let key = "tax=\(parent.taxonKey?.description ?? "-")|ds=\(parent.datasetKey ?? "-")|sp=\(parent.speciesKey?.description ?? "-")"
            guard key != currentOverlayKey else { return }
            map.overlays
                .compactMap { $0 as? GBIFDensityTileOverlay }
                .forEach(map.removeOverlay)
            let overlay = GBIFDensityTileOverlay(taxonKey: parent.taxonKey,
                                                 datasetKey: parent.datasetKey,
                                                 speciesKey: parent.speciesKey)
            map.addOverlay(overlay, level: .aboveLabels)
            currentOverlayKey = key
        }

        func applyPins(_ map: MKMapView) {
            let existing = map.annotations.compactMap { $0 as? OccurrencePin }
            map.removeAnnotations(existing)
            let pins = parent.pins.compactMap { occ -> OccurrencePin? in
                guard let lat = occ.decimalLatitude, let lng = occ.decimalLongitude else { return nil }
                return OccurrencePin(occurrence: occ, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            map.addAnnotations(pins)
        }

        @objc func longPress(_ gr: UILongPressGestureRecognizer) {
            guard gr.state == .began, let map = gr.view as? MKMapView else { return }
            let pt = gr.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            parent.onLongPress?(coord)
        }

        // MARK: Delegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let r = MKCircleRenderer(circle: circle)
                r.fillColor = UIColor.systemGreen.withAlphaComponent(0.10)
                r.strokeColor = UIColor.systemGreen.withAlphaComponent(0.7)
                r.lineWidth = 1
                return r
            }
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let pin = annotation as? OccurrencePin else { return nil }
            let id = "occurrence"
            let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: pin, reuseIdentifier: id)
            v.annotation = pin
            v.clusteringIdentifier = "occ"
            v.markerTintColor = .systemGreen
            v.canShowCallout = false
            return v
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? OccurrencePin else { return }
            parent.onPinTap(pin.occurrence)
            mapView.deselectAnnotation(view.annotation, animated: false)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange?(mapView.region)
        }

        private func same(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
            abs(a.latitude - b.latitude) < 1e-5 && abs(a.longitude - b.longitude) < 1e-5
        }
    }
}

final class OccurrencePin: NSObject, MKAnnotation {
    let occurrence: Occurrence
    let coordinate: CLLocationCoordinate2D
    var title: String? { occurrence.scientificName ?? occurrence.species }
    init(occurrence: Occurrence, coordinate: CLLocationCoordinate2D) {
        self.occurrence = occurrence
        self.coordinate = coordinate
    }
}
