import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class DatasetsViewModel {
    private let client: any GBIFClienting
    private var task: Task<Void, Never>?

    var rows: Loading<[DatasetRowItem]> = .idle

    init(client: any GBIFClienting) {
        self.client = client
    }

    func refresh(at coord: CLLocationCoordinate2D?, radiusKm: Double, taxonKey: Int?) async {
        task?.cancel()
        rows = .loading
        guard let coord else {
            rows = .loaded([])
            return
        }

        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.taxonKey = taxonKey
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
                                row.type = ds.type
                                row.license = ds.license
                                row.publisher = await Self.resolvePublisher(dataset: ds, client: captureClient)
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

                if Task.isCancelled { return }
                self?.rows = .loaded(enriched)
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

    /// GBIF's `/dataset/{key}` endpoint often returns `publishingOrganizationTitle: null` even when
    /// the publisher exists. Fall back to `/organization/{key}` so rows don't render as
    /// "Unknown publisher".
    static func resolvePublisher(dataset: Dataset, client: any GBIFClienting) async -> String? {
        if let title = dataset.publishingOrganizationTitle, title.isEmpty == false {
            return title
        }
        guard let orgKey = dataset.publishingOrganizationKey,
              let org = try? await client.organization(key: orgKey) else {
            return nil
        }
        return org.title
    }
}
