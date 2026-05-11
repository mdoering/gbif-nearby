import Foundation

protocol GBIFClienting: Sendable {
    func occurrenceSearch(_ query: OccurrenceQuery) async throws -> Page<Occurrence>
    func occurrenceCount(_ query: OccurrenceQuery) async throws -> Int
    func dataset(key: String) async throws -> Dataset
    func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset>
    func organization(key: String) async throws -> Organization
    func species(key: Int) async throws -> Species
    func vernacularNames(key: Int, language: String) async throws -> [VernacularName]
    func taxonSuggest(query: String, higherTaxonKey: Int?) async throws -> [TaxonSuggestion]
}
