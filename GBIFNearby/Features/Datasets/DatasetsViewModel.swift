import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class DatasetsViewModel {
    private let client: any GBIFClienting
    private let settings: SettingsStore
    private var task: Task<Void, Never>?

    var rows: Loading<[DatasetRowItem]> = .idle

    init(client: any GBIFClienting, settings: SettingsStore) {
        self.client = client
        self.settings = settings
    }

    func refresh(at coord: CLLocationCoordinate2D?, radiusKm: Double, kingdomKey: Int?, searchText: String) async {
        task?.cancel()
        rows = .loading
        if settings.datasetsGlobal {
            await runGlobal(searchText: searchText)
        } else {
            guard let coord else {
                rows = .loaded([])
                return
            }
            await runVicinity(coord: coord, radiusKm: radiusKm, kingdomKey: kingdomKey, searchText: searchText)
        }
    }

    // MARK: - Vicinity

    private func runVicinity(coord: CLLocationCoordinate2D, radiusKm: Double, kingdomKey: Int?, searchText: String) async {
        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.kingdomKey = kingdomKey
        q.facet = "datasetKey"
        q.facetLimit = 100
        q.facetMincount = 1
        q.limit = 0

        let captureClient = client
        let task = Task { [weak self] in
            do {
                let page = try await captureClient.occurrenceSearch(q)
                if Task.isCancelled { return }
                let buckets = page.facets?.first?.counts ?? []
                let head = Array(buckets.prefix(30))

                let enriched: [DatasetRowItem] = await withTaskGroup(of: (Int, DatasetRowItem).self,
                                                                     returning: [DatasetRowItem].self) { group in
                    for (idx, b) in head.enumerated() {
                        group.addTask { @Sendable in
                            var row = DatasetRowItem(key: b.name, nearbyCount: b.count)
                            if let ds = try? await captureClient.dataset(key: b.name) {
                                row.title = ds.title
                                row.publisher = ds.publishingOrganizationTitle
                                row.type = ds.type
                                row.license = ds.license
                            }
                            return (idx, row)
                        }
                    }
                    var result = head.enumerated().map { DatasetRowItem(key: $0.element.name, nearbyCount: $0.element.count) }
                    for await (idx, row) in group {
                        if idx < result.count { result[idx] = row }
                    }
                    return result
                }

                let filtered = Self.filterBySearch(rows: enriched, searchText: searchText)
                if Task.isCancelled { return }
                self?.rows = .loaded(filtered)
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self?.rows = .failed(error)
            } catch {
                self?.rows = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }

    // MARK: - Global

    private func runGlobal(searchText: String) async {
        rows = .loaded([])
    }

    // MARK: - Filtering

    static func filterBySearch(rows: [DatasetRowItem], searchText: String) -> [DatasetRowItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return rows }
        return rows.filter { row in
            (row.title?.lowercased().contains(query) ?? false)
            || (row.publisher?.lowercased().contains(query) ?? false)
        }
    }
}
