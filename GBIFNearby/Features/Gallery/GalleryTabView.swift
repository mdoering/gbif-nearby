import SwiftUI
import CoreLocation

struct GalleryTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(SettingsStore.self) private var settings
    @Environment(\.gbifClient) private var client

    @State private var viewModel: GalleryViewModel?
    @State private var debouncer = AsyncDebouncer(delay: .milliseconds(400))
    @State private var selectedTile: TileSelection?

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 110), spacing: 6)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                content
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .task { ensureViewModel() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFetch() }
            .onChange(of: taxon.selected) { _, _ in scheduleFetch() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFetch() }
            .onChange(of: focus.speciesKey) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFetch() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.tiles ?? .idle {
        case .idle, .loading:
            shimmer
        case .loaded(let items):
            if items.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, tile in
                            Button {
                                selectedTile = TileSelection(index: idx)
                            } label: {
                                GalleryTileView(tile: tile)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await viewModel?.loadMoreIfNeeded(currentTileID: tile.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    if let vm = viewModel, vm.isLoadingMore {
                        ProgressView().padding()
                    }
                }
                .refreshable { await refresh() }
                .navigationDestination(item: $selectedTile) { sel in
                    OccurrenceDetailView(tiles: items, startIndex: sel.index)
                }
            }
        case .failed(let err):
            VStack {
                ErrorBanner(message: err.userMessage) {
                    Task { await refresh() }
                }
                Spacer()
            }
        }
    }

    private var shimmer: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .redacted(reason: .placeholder)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "photo.on.rectangle").font(.largeTitle).foregroundStyle(.secondary)
            Text("No photos within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit)).")
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
            viewModel = GalleryViewModel(client: client)
        }
        Task { await refresh() }
    }

    private func scheduleFetch() {
        Task { await debouncer.schedule { await self.refresh() } }
    }

    private func refresh() async {
        guard let center = location.current, let vm = viewModel else { return }
        await vm.refresh(at: center,
                         radiusKm: radius.radiusKm,
                         kingdomKey: taxon.selected.taxonKey,
                         datasetKey: focus.datasetKey,
                         speciesKey: focus.speciesKey)
    }
}

/// Wraps an index in an Identifiable shell for navigationDestination(item:).
struct TileSelection: Identifiable, Hashable {
    let index: Int
    var id: Int { index }
}
