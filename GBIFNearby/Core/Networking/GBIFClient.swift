import Foundation

actor GBIFClient: GBIFClienting {
    private static let base = URL(string: "https://api.gbif.org/v1")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = GBIFClient.defaultSession()) {
        self.session = session
        let d = JSONDecoder()
        // GBIF v1 returns camelCase already, so no key strategy needed.
        self.decoder = d
    }

    static func defaultSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.timeoutIntervalForRequest = 15
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        cfg.httpAdditionalHeaders = ["User-Agent": "GBIFNearby/\(version) (iOS; org.gbif.nearby)"]
        return URLSession(configuration: cfg)
    }

    // MARK: - Endpoints

    func occurrenceSearch(_ query: OccurrenceQuery) async throws -> Page<Occurrence> {
        try await get("occurrence/search", items: query.queryItems())
    }

    func occurrenceCount(_ query: OccurrenceQuery) async throws -> Int {
        var q = query
        q.limit = 0
        let page: Page<Occurrence> = try await get("occurrence/search", items: q.queryItems())
        return page.count ?? 0
    }

    func dataset(key: String) async throws -> Dataset {
        try await get("dataset/\(key)", items: [])
    }

    func organization(key: String) async throws -> Organization {
        try await get("organization/\(key)", items: [])
    }

    func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset> {
        var items: [URLQueryItem] = [
            .init(name: "type", value: "OCCURRENCE"),
            .init(name: "limit", value: "20"),
            .init(name: "offset", value: String(page * 20)),
        ]
        if let q = query, q.isEmpty == false {
            items.append(.init(name: "q", value: q))
        }
        return try await get("dataset/search", items: items)
    }

    func species(key: Int) async throws -> Species {
        try await get("species/\(key)", items: [])
    }

    func vernacularNames(key: Int, language: String) async throws -> [VernacularName] {
        let page: Page<VernacularName> = try await get("species/\(key)/vernacularNames", items: [.init(name: "language", value: language)])
        return page.results
    }

    func taxonSuggest(query: String, higherTaxonKey: Int?) async throws -> [TaxonSuggestion] {
        var items: [URLQueryItem] = [
            .init(name: "q", value: query),
            .init(name: "limit", value: "12"),
        ]
        if let higherTaxonKey {
            items.append(.init(name: "higherTaxonKey", value: String(higherTaxonKey)))
        }
        // /species/suggest returns a bare JSON array (not a Page).
        return try await get("species/suggest", items: items)
    }

    // MARK: - Plumbing

    private func get<T: Decodable & Sendable>(_ path: String, items: [URLQueryItem]) async throws -> T {
        var comps = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if items.isEmpty == false { comps.queryItems = items }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw GBIFError.http(status: 0, message: "Non-HTTP response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8)
                throw GBIFError.http(status: http.statusCode, message: msg)
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch let e as DecodingError {
                throw GBIFError.decoding(e)
            }
        } catch let e as GBIFError {
            throw e
        } catch let e as URLError where e.code == .cancelled {
            throw GBIFError.cancelled
        } catch let e as URLError {
            throw GBIFError.network(e)
        }
    }
}
