import SwiftUI
import SafariServices

struct OccurrenceDetailView: View {
    let tiles: [GalleryTile]
    let startIndex: Int
    @Environment(SettingsStore.self) private var settings
    @Environment(\.gbifClient) private var client

    @State private var pageIndex: Int = 0
    @State private var vernacularByKey: [Int: String?] = [:]
    @State private var showSafari = false

    var body: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(tiles.enumerated()), id: \.element.id) { idx, tile in
                page(for: tile)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(currentTile?.displayName ?? "Occurrence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSafari = true
                } label: {
                    Image(systemName: "safari")
                }
                .disabled(currentTile == nil)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let tile = currentTile {
                SafariView(url: URL(string: "https://www.gbif.org/occurrence/\(tile.occurrence.key)")!)
                    .ignoresSafeArea()
            }
        }
        .onAppear { pageIndex = startIndex }
        .task(id: pageIndex) {
            await loadVernacularIfNeeded()
        }
    }

    private var currentTile: GalleryTile? {
        guard tiles.indices.contains(pageIndex) else { return nil }
        return tiles[pageIndex]
    }

    @ViewBuilder
    private func page(for tile: GalleryTile) -> some View {
        VStack(spacing: 0) {
            let url = ImageCacheURL.build(occurrenceKey: tile.occurrence.key,
                                          identifier: tile.identifier,
                                          size: .width(1200))
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .empty:
                    ProgressView().tint(.white)
                case .failure:
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
                @unknown default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)

            metadata(for: tile)
        }
    }

    @ViewBuilder
    private func metadata(for tile: GalleryTile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tile.displayName).font(.headline.italic()).lineLimit(2)
            if let speciesKey = tile.occurrence.speciesKey,
               let cached = vernacularByKey[speciesKey], let v = cached {
                Text(v).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let date = tile.occurrence.eventDate {
                    Label(date, systemImage: "calendar").labelStyle(.titleAndIcon)
                }
                if let recorder = tile.occurrence.recordedBy {
                    Label(recorder, systemImage: "person").lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let dsKey = tile.occurrence.datasetKey {
                Text("Dataset: \(dsKey)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let media = tile.occurrence.media,
               media.indices.contains(tile.mediaIndex),
               let license = media[tile.mediaIndex].license,
               license.isEmpty == false {
                Text(license).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
    }

    private func loadVernacularIfNeeded() async {
        guard let tile = currentTile,
              let speciesKey = tile.occurrence.speciesKey,
              vernacularByKey[speciesKey] == nil else { return }
        let lang = VernacularResolver.effectiveLanguage(
            userPreference: settings.vernacularLanguage,
            deviceLanguageCode: Locale.current.language.languageCode?.identifier
        )
        let names = (try? await client.vernacularNames(key: speciesKey, language: lang)) ?? []
        let chosen = VernacularResolver.choose(from: names, language: lang)
        if chosen == nil && lang != "en" {
            let en = (try? await client.vernacularNames(key: speciesKey, language: "en")) ?? []
            vernacularByKey[speciesKey] = VernacularResolver.choose(from: en, language: "en")
        } else {
            vernacularByKey[speciesKey] = chosen
        }
    }
}
