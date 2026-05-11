import SwiftUI
import SafariServices

struct OccurrenceSheet: View {
    let occurrence: Occurrence

    var body: some View {
        NavigationStack {
            OccurrenceDetailContent(occurrence: occurrence)
        }
        .presentationDetents([.medium, .large])
    }
}

/// The content of an occurrence detail — image header (when the record has photos)
/// plus a metadata Form. Hosted both inside `OccurrenceSheet` (single-pin tap) and
/// pushed from `ClusterPickerSheet` (one of several co-located records).
struct OccurrenceDetailContent: View {
    let occurrence: Occurrence
    @Environment(\.gbifClient) private var client
    @State private var showSafari = false
    @State private var selectedTile: TileSelection?
    @State private var datasetTitle: String?

    private var tiles: [GalleryTile] {
        (occurrence.media ?? []).enumerated().compactMap { idx, m in
            guard m.type == "StillImage",
                  let id = m.identifier, id.isEmpty == false else { return nil }
            return GalleryTile(occurrence: occurrence, mediaIndex: idx, identifier: id)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if tiles.isEmpty == false {
                imageHeader
            }
            Form {
                Section {
                    if let name = occurrence.scientificName ?? occurrence.species {
                        Text(name).font(.title3.italic())
                    }
                    if let kingdom = occurrence.kingdom { row("Kingdom", kingdom) }
                    if let family = occurrence.family { row("Family", family) }
                    if let date = occurrence.eventDate { row("Date", date) }
                    if let recorder = occurrence.recordedBy { row("Recorded by", recorder) }
                    if let basis = occurrence.basisOfRecord { row("Basis", basis) }
                    if let title = datasetTitle { row("Dataset", title) }
                }
                Section {
                    Button("View on GBIF.org") { showSafari = true }
                }
            }
        }
        .navigationTitle("Occurrence #\(occurrence.key)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: "https://www.gbif.org/occurrence/\(occurrence.key)")!)
                .ignoresSafeArea()
        }
        .navigationDestination(item: $selectedTile) { sel in
            OccurrenceDetailView(tiles: tiles, startIndex: sel.index)
        }
        .task { await loadDatasetTitle() }
    }

    private func loadDatasetTitle() async {
        guard let key = occurrence.datasetKey, datasetTitle == nil else { return }
        if let ds = try? await client.dataset(key: key) {
            datasetTitle = ds.title
        }
    }

    @ViewBuilder
    private var imageHeader: some View {
        TabView {
            ForEach(Array(tiles.enumerated()), id: \.element.id) { idx, tile in
                Button {
                    selectedTile = TileSelection(index: idx)
                } label: {
                    AsyncImage(
                        url: ImageCacheURL.build(
                            occurrenceKey: tile.occurrence.key,
                            identifier: tile.identifier,
                            size: .width(800)
                        )
                    ) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        case .empty:
                            ProgressView().tint(.white)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.5))
                        @unknown default: EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: tiles.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 240)
        .background(Color.black)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
