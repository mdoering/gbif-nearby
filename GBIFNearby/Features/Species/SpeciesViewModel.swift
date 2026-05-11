import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class SpeciesViewModel {
    private let client: any GBIFClienting
    private let settings: SettingsStore
    private var task: Task<Void, Never>?
    private var enrichTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var vernacularCache: [VernacularCacheKey: String?] = [:]

    var rows: Loading<[SpeciesRowItem]> = .idle

    init(client: any GBIFClienting, settings: SettingsStore) {
        self.client = client
        self.settings = settings
    }

    func refresh(at coord: CLLocationCoordinate2D, radiusKm: Double,
                 kingdomKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        enrichTask?.cancel()
        thumbnailTask?.cancel()
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

    /// Concurrently enrich the first `limit` rows with /species/{key} and vernacular lookups.
    func enrichTopRows(limit: Int = 30) async {
        guard case .loaded(let items) = rows else { return }
        let lang = VernacularResolver.effectiveLanguage(
            userPreference: settings.vernacularLanguage,
            deviceLanguageCode: Locale.current.language.languageCode?.identifier
        )
        let head = Array(items.prefix(limit))
        let tail = Array(items.dropFirst(limit))
        let cacheSnapshot = vernacularCache
        let captureClient = client

        enrichTask?.cancel()
        let work = Task { @MainActor [weak self] in
            guard let self else { return }
            let enriched = await withTaskGroup(of: (Int, SpeciesRowItem).self, returning: [SpeciesRowItem].self) { group in
                for (index, item) in head.enumerated() {
                    group.addTask { @Sendable in
                        var row = item
                        if let s = try? await captureClient.species(key: item.speciesKey) {
                            row.scientificName = s.scientificName ?? s.canonicalName
                            row.canonicalName = s.canonicalName
                            row.authorship = s.authorship
                            row.kingdom = s.kingdom
                            row.phylum = s.phylum
                            row.classRank = s.`class`
                            row.order = s.order
                            row.family = s.family
                            row.genus = s.genus
                        }
                        let cacheKey = VernacularCacheKey(speciesKey: item.speciesKey, language: lang)
                        if let cached = cacheSnapshot[cacheKey] {
                            row.vernacularName = cached
                        } else {
                            row.vernacularName = await Self.resolveVernacular(
                                speciesKey: item.speciesKey, language: lang, client: captureClient)
                        }
                        return (index, row)
                    }
                }
                var result = head
                for await (index, row) in group {
                    if index < result.count { result[index] = row }
                }
                return result
            }
            if Task.isCancelled { return }
            self.rows = .loaded(enriched + tail)
            for row in enriched {
                let cacheKey = VernacularCacheKey(speciesKey: row.speciesKey, language: lang)
                self.vernacularCache[cacheKey] = row.vernacularName
            }
        }
        enrichTask = work
        await work.value
    }

    private static func resolveVernacular(speciesKey: Int, language: String, client: any GBIFClienting) async -> String? {
        let names = (try? await client.vernacularNames(key: speciesKey, language: language)) ?? []
        if let chosen = VernacularResolver.choose(from: names, language: language) { return chosen }
        if language != "en" {
            let en = (try? await client.vernacularNames(key: speciesKey, language: "en")) ?? []
            return VernacularResolver.choose(from: en, language: "en")
        }
        return nil
    }

    /// For each of the first `limit` rows, look up one occurrence with a still image
    /// and store a ThumbnailRef. Runs concurrently.
    func fetchThumbnails(limit: Int = 30) async {
        guard case .loaded(let items) = rows else { return }
        let head = Array(items.prefix(limit))
        let tail = Array(items.dropFirst(limit))
        let captureClient = client

        thumbnailTask?.cancel()
        let work = Task { @MainActor [weak self] in
            guard let self else { return }
            let enriched = await withTaskGroup(of: (Int, SpeciesRowItem).self, returning: [SpeciesRowItem].self) { group in
                for (index, item) in head.enumerated() {
                    group.addTask { @Sendable in
                        var row = item
                        if row.thumbnail != nil { return (index, row) }
                        var q = OccurrenceQuery()
                        q.speciesKey = item.speciesKey
                        q.mediaType = "StillImage"
                        q.limit = 1
                        let page = try? await captureClient.occurrenceSearch(q)
                        if let occ = page?.results.first,
                           let media = occ.media?.first(where: { $0.type == "StillImage" }),
                           let id = media.identifier {
                            row.thumbnail = ThumbnailRef(occurrenceKey: occ.key, mediaIdentifier: id)
                        }
                        return (index, row)
                    }
                }
                var result = head
                for await (index, row) in group {
                    if index < result.count { result[index] = row }
                }
                return result
            }
            if Task.isCancelled { return }
            self.rows = .loaded(enriched + tail)
        }
        thumbnailTask = work
        await work.value
    }
}

private struct VernacularCacheKey: Hashable {
    let speciesKey: Int
    let language: String
}
