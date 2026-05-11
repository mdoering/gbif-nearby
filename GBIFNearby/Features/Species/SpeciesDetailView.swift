import SwiftUI

struct SpeciesDetailView: View {
    let item: SpeciesRowItem
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(\.gbifClient) private var client
    @Environment(FocusFilterStore.self) private var focus
    @Environment(TabSelectionStore.self) private var tabSelection

    @State private var globalCount: Int?
    @State private var nearbyCount: Int?
    @State private var carouselImages: [ThumbnailRef] = []
    @State private var showSafari = false

    var body: some View {
        Form {
            if carouselImages.isEmpty == false {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(carouselImages.enumerated()), id: \.offset) { _, ref in
                                let url = ImageCacheURL.build(occurrenceKey: ref.occurrenceKey,
                                                              identifier: ref.mediaIdentifier,
                                                              size: .width(400))
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Color(.tertiarySystemFill)
                                    }
                                }
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
            }

            Section {
                if let name = item.scientificName ?? item.canonicalName {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(name).font(.title3.italic())
                        if let a = item.authorship {
                            Text(a).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let v = item.vernacularName {
                    Text(v).foregroundStyle(.secondary)
                }
            }

            if let kingdom = item.kingdom {
                Section("Classification") {
                    Text(kingdom)
                }
            }

            Section("Occurrences") {
                statRow("Within \(String(format: "%.1f", radius.radiusKm)) km", value: item.count)
                statRow("Total on GBIF", value: globalCount)
                statRow("Within radius (live)", value: nearbyCount)
            }

            Section {
                Button("View on GBIF.org") { showSafari = true }
            }

            Section {
                Button {
                    let label = item.scientificName ?? item.canonicalName ?? "#\(item.speciesKey)"
                    focus.set(speciesKey: item.speciesKey, label: label)
                    tabSelection.current = .map
                } label: {
                    Label("Show on map", systemImage: "map")
                }
            }
        }
        .navigationTitle("Species")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: "https://www.gbif.org/species/\(item.speciesKey)")!)
                .ignoresSafeArea()
        }
        .task { await loadDetails() }
    }

    @ViewBuilder
    private func statRow(_ label: String, value: Int?) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if let v = value {
                Text(v, format: .number).monospacedDigit()
            } else {
                ProgressView().controlSize(.mini)
            }
        }
    }

    private func loadDetails() async {
        async let global: Int? = {
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            return try? await client.occurrenceCount(q)
        }()
        async let nearby: Int? = {
            guard let coord = location.current else { return nil }
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            q.lat = coord.latitude
            q.lng = coord.longitude
            q.radiusKm = radius.radiusKm
            return try? await client.occurrenceCount(q)
        }()
        async let media: [ThumbnailRef] = {
            // Local first; top up globally if too few.
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            q.mediaType = "StillImage"
            q.limit = 12
            if let coord = location.current {
                q.lat = coord.latitude
                q.lng = coord.longitude
                q.radiusKm = radius.radiusKm
            }
            var refs = extract(page: try? await client.occurrenceSearch(q))
            if refs.count < 6 {
                var fallback = OccurrenceQuery()
                fallback.speciesKey = item.speciesKey
                fallback.mediaType = "StillImage"
                fallback.limit = 12
                refs += extract(page: try? await client.occurrenceSearch(fallback))
            }
            return Array(refs.prefix(12))
        }()

        let (g, n, m) = await (global, nearby, media)
        globalCount = g
        nearbyCount = n
        carouselImages = m
    }

    private func extract(page: Page<Occurrence>?) -> [ThumbnailRef] {
        guard let results = page?.results else { return [] }
        var out: [ThumbnailRef] = []
        for occ in results {
            for media in occ.media ?? [] where media.type == "StillImage" {
                if let id = media.identifier {
                    out.append(ThumbnailRef(occurrenceKey: occ.key, mediaIdentifier: id))
                }
            }
        }
        return out
    }
}
