import SwiftUI
import CoreLocation

struct SpeciesTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(SettingsStore.self) private var settings
    @Environment(\.gbifClient) private var client

    @State private var viewModel: SpeciesViewModel?
    @State private var debouncer = AsyncDebouncer(delay: .milliseconds(400))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                content
            }
            .navigationTitle("Species")
            .navigationBarTitleDisplayMode(.inline)
            .task { ensureViewModel() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFetch() }
            .onChange(of: taxon.effectiveTaxonKey) { _, _ in scheduleFetch() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFetch() }
            .onChange(of: focus.speciesKey) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFetch() }
            .onChange(of: settings.vernacularLanguage) { _, _ in scheduleFetch() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.rows ?? .idle {
        case .idle, .loading:
            shimmer
        case .loaded(let items):
            if items.isEmpty {
                empty
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            SpeciesDetailView(item: item)
                        } label: {
                            SpeciesListRow(item: item)
                        }
                        .onAppear {
                            Task {
                                await viewModel?.enrichRowIfNeeded(speciesKey: item.speciesKey)
                                await viewModel?.fetchThumbnailIfNeeded(speciesKey: item.speciesKey)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await fetchAll()
                }
            }
        case .failed(let err):
            VStack {
                ErrorBanner(message: err.userMessage) {
                    Task { await fetchAll() }
                }
                Spacer()
            }
        }
    }

    private var shimmer: some View {
        List(0..<8, id: \.self) { _ in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.tertiarySystemFill)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 3).fill(Color(.tertiarySystemFill)).frame(width: 120, height: 10)
                }
            }
            .redacted(reason: .placeholder)
            .padding(.vertical, 2)
        }
        .listStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "leaf").font(.largeTitle).foregroundStyle(.secondary)
            Text("No species recorded within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit)).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Try a larger radius or different group.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = SpeciesViewModel(client: client, settings: settings)
            Task { await fetchAll() }
        }
    }

    private func scheduleFetch() {
        Task {
            await debouncer.schedule { await self.fetchAll() }
        }
    }

    private func fetchAll() async {
        guard let center = location.current, let vm = viewModel else { return }
        await vm.refresh(at: center,
                         radiusKm: radius.radiusKm,
                         taxonKey: taxon.effectiveTaxonKey,
                         datasetKey: focus.datasetKey,
                         speciesKey: focus.speciesKey)
        await vm.enrichTopRows(limit: 30)
        await vm.fetchThumbnails(limit: 30)
    }
}
