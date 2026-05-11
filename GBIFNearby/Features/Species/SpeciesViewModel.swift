import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class SpeciesViewModel {
    private let client: any GBIFClienting
    private let settings: SettingsStore
    private var task: Task<Void, Never>?
    private var vernacularCache: [VernacularCacheKey: String?] = [:]

    // Per-row enrichment bookkeeping. Cleared on each refresh().
    // `enriched` / `thumbnailed` mean "already processed (success OR no data)" so
    // we don't keep retrying. `inFlight…` short-circuits concurrent callers
    // (e.g. List rendering many `.onAppear` in the same frame).
    private var enrichedKeys: Set<Int> = []
    private var thumbnailedKeys: Set<Int> = []
    private var inFlightEnrichment: Set<Int> = []
    private var inFlightThumbnails: Set<Int> = []

    var rows: Loading<[SpeciesRowItem]> = .idle

    init(client: any GBIFClienting, settings: SettingsStore) {
        self.client = client
        self.settings = settings
    }

    func refresh(at coord: CLLocationCoordinate2D, radiusKm: Double,
                 taxonKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        rows = .loading
        enrichedKeys.removeAll()
        thumbnailedKeys.removeAll()
        inFlightEnrichment.removeAll()
        inFlightThumbnails.removeAll()

        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.taxonKey = taxonKey
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

    /// Concurrently enrich the first `limit` rows. Used at initial load so the
    /// top of the list paints quickly without waiting for `.onAppear`.
    func enrichTopRows(limit: Int = 30) async {
        guard case .loaded(let items) = rows else { return }
        let head = Array(items.prefix(limit))
        await withTaskGroup(of: Void.self) { group in
            for item in head {
                group.addTask { @Sendable [weak self] in
                    await self?.enrichRowIfNeeded(speciesKey: item.speciesKey)
                }
            }
        }
    }

    /// Concurrently fetch thumbnails for the first `limit` rows.
    func fetchThumbnails(limit: Int = 30) async {
        guard case .loaded(let items) = rows else { return }
        let head = Array(items.prefix(limit))
        await withTaskGroup(of: Void.self) { group in
            for item in head {
                group.addTask { @Sendable [weak self] in
                    await self?.fetchThumbnailIfNeeded(speciesKey: item.speciesKey)
                }
            }
        }
    }

    /// Fetch species details + vernacular for one row. Idempotent — repeat calls
    /// for the same key while a fetch is in flight, or after one completed, return
    /// immediately. Drives the List's `.onAppear` lazy-loading.
    func enrichRowIfNeeded(speciesKey: Int) async {
        if enrichedKeys.contains(speciesKey) || inFlightEnrichment.contains(speciesKey) { return }
        inFlightEnrichment.insert(speciesKey)
        defer { inFlightEnrichment.remove(speciesKey) }

        let lang = VernacularResolver.effectiveLanguage(
            userPreference: settings.vernacularLanguage,
            deviceLanguageCode: Locale.current.language.languageCode?.identifier
        )
        let cacheKey = VernacularCacheKey(speciesKey: speciesKey, language: lang)
        let cachedVernacular = vernacularCache[cacheKey]

        async let speciesFetch: Species? = try? await client.species(key: speciesKey)
        async let vernacularFetch: String? = {
            if let cached = cachedVernacular { return cached }
            return await Self.resolveVernacular(speciesKey: speciesKey, language: lang, client: client)
        }()
        let species = await speciesFetch
        let vernacular = await vernacularFetch

        vernacularCache[cacheKey] = vernacular
        enrichedKeys.insert(speciesKey)

        guard case .loaded(var items) = rows,
              let idx = items.firstIndex(where: { $0.speciesKey == speciesKey }) else { return }
        var row = items[idx]
        if let s = species {
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
        row.vernacularName = vernacular
        items[idx] = row
        rows = .loaded(items)
    }

    /// Find one still-image occurrence for this species and stash a ThumbnailRef.
    func fetchThumbnailIfNeeded(speciesKey: Int) async {
        if thumbnailedKeys.contains(speciesKey) || inFlightThumbnails.contains(speciesKey) { return }
        inFlightThumbnails.insert(speciesKey)
        defer { inFlightThumbnails.remove(speciesKey) }

        var q = OccurrenceQuery()
        q.speciesKey = speciesKey
        q.mediaType = "StillImage"
        q.limit = 1
        let page = try? await client.occurrenceSearch(q)
        thumbnailedKeys.insert(speciesKey)

        guard let occ = page?.results.first,
              let media = occ.media?.first(where: { $0.type == "StillImage" }),
              let id = media.identifier,
              case .loaded(var items) = rows,
              let idx = items.firstIndex(where: { $0.speciesKey == speciesKey }) else { return }
        var row = items[idx]
        if row.thumbnail == nil {
            row.thumbnail = ThumbnailRef(occurrenceKey: occ.key, mediaIdentifier: id)
            items[idx] = row
            rows = .loaded(items)
        }
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
}

private struct VernacularCacheKey: Hashable {
    let speciesKey: Int
    let language: String
}
