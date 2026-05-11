import SwiftUI

/// Modal search/autocomplete for picking a GBIF taxon. Selecting a result writes
/// `taxonOverride` on the shared `TaxonFilterStore`. The kingdom chip selection (if any)
/// is used as `higherTaxonKey` to scope suggestions.
struct TaxonSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(\.gbifClient) private var client

    @State private var query: String = ""
    @State private var suggestions: [TaxonSuggestion] = []
    @State private var loadingState: Loading<[TaxonSuggestion]> = .idle
    @State private var debouncer = AsyncDebouncer(delay: .milliseconds(250))

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search taxon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    if taxon.taxonOverride != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Clear", role: .destructive) {
                                taxon.taxonOverride = nil
                                dismiss()
                            }
                        }
                    }
                }
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                            prompt: prompt)
                .onChange(of: query) { _, _ in scheduleSearch() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadingState {
        case .idle:
            ContentUnavailableView("Type at least 2 letters",
                                   systemImage: "magnifyingglass",
                                   description: Text(prompt))
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let items):
            if items.isEmpty {
                ContentUnavailableView("No matches", systemImage: "magnifyingglass")
            } else {
                List(items) { s in
                    Button {
                        taxon.taxonOverride = s
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.scientificName).font(.body.italic())
                            if let rank = s.rank, rank.isEmpty == false {
                                Text(rank.lowercased()).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        case .failed(let err):
            ContentUnavailableView("Search failed",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text(err.userMessage))
        }
    }

    private var prompt: String {
        if let kingdom = taxon.selected {
            return "Searching within \(kingdom.displayLabel)"
        }
        return "e.g. Bombus, Asteraceae, Quercus"
    }

    private func scheduleSearch() {
        let captured = query
        Task {
            await debouncer.schedule {
                await self.runSearch(captured)
            }
        }
    }

    private func runSearch(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            loadingState = .idle
            return
        }
        loadingState = .loading
        let higher = taxon.selected?.taxonKey
        do {
            let results = try await client.taxonSuggest(query: trimmed, higherTaxonKey: higher)
            // Make sure the in-flight query didn't get superseded.
            guard trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            loadingState = .loaded(results)
        } catch let e as GBIFError {
            loadingState = .failed(e)
        } catch {
            loadingState = .failed(.network(URLError(.unknown)))
        }
    }
}

#Preview {
    TaxonSearchSheet()
        .environment(TaxonFilterStore())
}
