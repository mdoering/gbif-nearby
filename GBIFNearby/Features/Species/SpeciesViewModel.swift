import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class SpeciesViewModel {
    private let client: any GBIFClienting
    private let settings: SettingsStore
    private var task: Task<Void, Never>?

    var rows: Loading<[SpeciesRowItem]> = .idle

    init(client: any GBIFClienting, settings: SettingsStore) {
        self.client = client
        self.settings = settings
    }

    /// Fetch the speciesKey facet for the current filters; do not enrich yet.
    func refresh(at coord: CLLocationCoordinate2D, radiusKm: Double,
                 kingdomKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        rows = .loading

        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.kingdomKey = kingdomKey
        q.datasetKey = datasetKey
        q.speciesKey = speciesKey
        q.facet = "speciesKey"
        q.facetLimit = 100
        q.facetMincount = 1
        q.limit = 0

        let task = Task { [client] in
            do {
                let page = try await client.occurrenceSearch(q)
                if Task.isCancelled { return }
                let buckets = page.facets?.first?.counts ?? []
                let items: [SpeciesRowItem] = buckets.compactMap { b in
                    guard let key = Int(b.name) else { return nil }
                    return SpeciesRowItem(speciesKey: key, count: b.count)
                }
                self.rows = .loaded(items)
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self.rows = .failed(error)
            } catch {
                self.rows = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }
}
