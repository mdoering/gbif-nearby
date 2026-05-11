import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class MapViewModel {
    private let client: any GBIFClienting
    private var task: Task<Void, Never>?

    var pins: Loading<[Occurrence]> = .idle

    init(client: any GBIFClienting) {
        self.client = client
    }

    func fetchPins(at coord: CLLocationCoordinate2D, radiusKm: Double,
                   taxonKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        pins = .loading
        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.taxonKey = taxonKey
        q.datasetKey = datasetKey
        q.speciesKey = speciesKey
        q.hasCoordinate = true
        q.limit = 300
        let task = Task { [client] in
            do {
                let page = try await client.occurrenceSearch(q)
                if Task.isCancelled { return }
                self.pins = .loaded(page.results.filter { $0.decimalLatitude != nil && $0.decimalLongitude != nil })
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self.pins = .failed(error)
            } catch {
                self.pins = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }

    func clearPins() {
        task?.cancel()
        pins = .idle
    }
}
