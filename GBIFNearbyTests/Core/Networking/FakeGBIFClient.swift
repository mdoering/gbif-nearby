import Foundation
@testable import GBIFNearby

actor FakeGBIFClient: GBIFClienting {
    var recordedSearches: [OccurrenceQuery] = []
    var recordedCounts: [OccurrenceQuery] = []
    var recordedDatasetSearches: [(query: String?, page: Int)] = []
    var recordedDatasetKeys: [String] = []
    var recordedSpeciesKeys: [Int] = []
    var recordedVernacularRequests: [(key: Int, lang: String)] = []

    var searchHandler: (@Sendable (OccurrenceQuery) async throws -> Page<Occurrence>)?
    var countHandler: (@Sendable (OccurrenceQuery) async throws -> Int)?
    var datasetHandler: (@Sendable (String) async throws -> Dataset)?
    var datasetSearchHandler: (@Sendable (String?, Int) async throws -> Page<Dataset>)?
    var speciesHandler: (@Sendable (Int) async throws -> Species)?
    var vernacularHandler: (@Sendable (Int, String) async throws -> [VernacularName])?

    func setSearch(_ h: @escaping @Sendable (OccurrenceQuery) async throws -> Page<Occurrence>) { searchHandler = h }
    func setCount(_ h: @escaping @Sendable (OccurrenceQuery) async throws -> Int) { countHandler = h }
    func setDataset(_ h: @escaping @Sendable (String) async throws -> Dataset) { datasetHandler = h }
    func setDatasetSearch(_ h: @escaping @Sendable (String?, Int) async throws -> Page<Dataset>) { datasetSearchHandler = h }
    func setSpecies(_ h: @escaping @Sendable (Int) async throws -> Species) { speciesHandler = h }
    func setVernacular(_ h: @escaping @Sendable (Int, String) async throws -> [VernacularName]) { vernacularHandler = h }

    func occurrenceSearch(_ query: OccurrenceQuery) async throws -> Page<Occurrence> {
        recordedSearches.append(query)
        return try await (searchHandler ?? { _ in Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [], facets: nil) })(query)
    }
    func occurrenceCount(_ query: OccurrenceQuery) async throws -> Int {
        recordedCounts.append(query)
        return try await (countHandler ?? { _ in 0 })(query)
    }
    func dataset(key: String) async throws -> Dataset {
        recordedDatasetKeys.append(key)
        guard let h = datasetHandler else { throw GBIFError.cancelled }
        return try await h(key)
    }
    func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset> {
        recordedDatasetSearches.append((query, page))
        return try await (datasetSearchHandler ?? { _, _ in Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [], facets: nil) })(query, page)
    }
    func species(key: Int) async throws -> Species {
        recordedSpeciesKeys.append(key)
        guard let h = speciesHandler else { throw GBIFError.cancelled }
        return try await h(key)
    }
    func vernacularNames(key: Int, language: String) async throws -> [VernacularName] {
        recordedVernacularRequests.append((key, language))
        return try await (vernacularHandler ?? { _, _ in [] })(key, language)
    }
}
