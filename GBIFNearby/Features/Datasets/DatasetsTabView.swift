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
    @State private var searchText: String = ""
    @State private var searchDebouncer = AsyncDebouncer(delay: .milliseconds(300))
    @State private var filterDebouncer = AsyncDebouncer(delay: .milliseconds(400))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                modeToggle
                content
            }
            .navigationTitle("Datasets")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.datasetsGlobal ? "Search GBIF datasets" : "Filter nearby datasets")
            .task { ensureViewModel() }
            .onChange(of: searchText) { _, _ in scheduleSearch() }
            .onChange(of: settings.datasetsGlobal) { _, _ in scheduleFilter() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFilter() }
            .onChange(of: taxon.selected) { _, _ in scheduleFilter() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFilter() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFilter() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFilter() }
        }
    }

    private var modeToggle: some View {
        @Bindable var bindableSettings = settings
        return Toggle(isOn: $bindableSettings.datasetsGlobal) {
            Text("Search all GBIF datasets")
                .font(.footnote)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
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
                            DatasetDetailViewStub(item: item)
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
            Text(settings.datasetsGlobal
                 ? "No datasets match \"\(searchText)\"."
                 : "No datasets have records within \(String(format: "%.1f", radius.radiusKm)) km.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = DatasetsViewModel(client: client, settings: settings)
        }
        Task { await fetch() }
    }

    private func scheduleSearch() {
        Task { await searchDebouncer.schedule { await self.fetch() } }
    }

    private func scheduleFilter() {
        Task { await filterDebouncer.schedule { await self.fetch() } }
    }

    private func fetch() async {
        guard let vm = viewModel else { return }
        await vm.refresh(at: location.current,
                         radiusKm: radius.radiusKm,
                         kingdomKey: taxon.selected.taxonKey,
                         searchText: searchText)
    }
}

// Temporary stub — replaced in Task 8.
private struct DatasetDetailViewStub: View {
    let item: DatasetRowItem
    var body: some View {
        Text("Detail for \(item.title ?? item.key) (coming in Task 8)")
            .navigationTitle("Dataset")
            .navigationBarTitleDisplayMode(.inline)
    }
}
