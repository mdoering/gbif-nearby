import SwiftUI

struct SpeciesDetailView: View {
    let item: SpeciesRowItem
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(\.gbifClient) private var client

    @State private var globalCount: Int?
    @State private var nearbyCount: Int?
    @State private var carouselImages: [ThumbnailRef] = []
    @State private var showSafari = false

    var body: some View {
        Form {
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
        let (g, n) = await (global, nearby)
        globalCount = g
        nearbyCount = n
    }
}
