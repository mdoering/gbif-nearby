import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class GalleryViewModel {
    static let pageSize = 50
    static let maxTiles = 500

    private let client: any GBIFClienting
    private var task: Task<Void, Never>?
    private var nextOffset: Int = 0
    private var lastQuery: OccurrenceQuery?

    var tiles: Loading<[GalleryTile]> = .idle
    var endOfResults: Bool = false
    var isLoadingMore: Bool = false

    init(client: any GBIFClienting) {
        self.client = client
    }

    func refresh(at coord: CLLocationCoordinate2D, radiusKm: Double,
                 taxonKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        nextOffset = 0
        endOfResults = false
        tiles = .loading

        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.taxonKey = taxonKey
        q.datasetKey = datasetKey
        q.speciesKey = speciesKey
        q.mediaType = "StillImage"
        q.hasCoordinate = true
        q.limit = Self.pageSize
        q.offset = 0
        lastQuery = q

        let captureClient = client
        let task = Task { [weak self] in
            do {
                let page = try await captureClient.occurrenceSearch(q)
                if Task.isCancelled { return }
                guard let self else { return }
                let flat = Self.flatten(page: page)
                self.tiles = .loaded(flat)
                self.nextOffset = Self.pageSize
                self.endOfResults = page.endOfRecords ?? false
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self?.tiles = .failed(error)
            } catch {
                self?.tiles = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }

    func loadMoreIfNeeded(currentTileID: String) async {
        guard isLoadingMore == false, endOfResults == false else { return }
        guard case .loaded(let current) = tiles else { return }
        guard current.count < Self.maxTiles else {
            endOfResults = true
            return
        }
        guard let idx = current.firstIndex(where: { $0.id == currentTileID }),
              idx >= max(1, current.count - 10) else {
            return
        }
        guard var q = lastQuery else { return }
        q.offset = nextOffset
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await client.occurrenceSearch(q)
            if Task.isCancelled { return }
            let flat = Self.flatten(page: page)
            var combined = current + flat
            if combined.count > Self.maxTiles {
                combined = Array(combined.prefix(Self.maxTiles))
                endOfResults = true
            }
            tiles = .loaded(combined)
            nextOffset += Self.pageSize
            if endOfResults == false {
                endOfResults = page.endOfRecords ?? false
            }
        } catch {
            // Silent on pagination failure — leave existing tiles in place.
        }
    }

    static func flatten(page: Page<Occurrence>) -> [GalleryTile] {
        var out: [GalleryTile] = []
        for occ in page.results {
            guard let media = occ.media else { continue }
            for (idx, m) in media.enumerated() where m.type == "StillImage" {
                guard let id = m.identifier, id.isEmpty == false else { continue }
                out.append(GalleryTile(occurrence: occ, mediaIndex: idx, identifier: id))
            }
        }
        return out
    }
}
