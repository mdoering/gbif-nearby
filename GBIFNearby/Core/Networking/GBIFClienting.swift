import Foundation

protocol GBIFClienting: Sendable {
    func occurrenceSearch(_ query: OccurrenceQuery) async throws -> Page<Occurrence>
    func occurrenceCount(_ query: OccurrenceQuery) async throws -> Int
    func dataset(key: String) async throws -> Dataset
    func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset>
    func species(key: Int) async throws -> Species
    func vernacularNames(key: Int, language: String) async throws -> [VernacularName]
}
