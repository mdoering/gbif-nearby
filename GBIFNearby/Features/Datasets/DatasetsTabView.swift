import SwiftUI
import CoreLocation

struct DatasetsTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(SettingsStore.self) private var settings
    @Environment(\.gbifClient) private var client

    @State private var viewModel: DatasetsViewModel?
    @State private var filterDebouncer = AsyncDebouncer(delay: .milliseconds(400))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                content
            }
            .navigationTitle("Datasets")
            .navigationBarTitleDisplayMode(.inline)
            .task { ensureViewModel() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFilter() }
            .onChange(of: taxon.effectiveTaxonKey) { _, _ in scheduleFilter() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFilter() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFilter() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFilter() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.rows ?? .idle {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let items):
            if items.isEmpty {
                empty
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            DatasetDetailView(item: item)
                        } label: {
                            DatasetRow(item: item)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await fetch() }
            }
        case .failed(let err):
            VStack {
                ErrorBanner(message: err.userMessage) {
                    Task { await fetch() }
                }
                Spacer()
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
            Text("No datasets have records within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit)).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = DatasetsViewModel(client: client)
            Task { await fetch() }
        }
    }

    private func scheduleFilter() {
        Task { await filterDebouncer.schedule { await self.fetch() } }
    }

    private func fetch() async {
        guard let vm = viewModel else { return }
        await vm.refresh(at: location.current,
                         radiusKm: radius.radiusKm,
                         taxonKey: taxon.effectiveTaxonKey)
    }
}
