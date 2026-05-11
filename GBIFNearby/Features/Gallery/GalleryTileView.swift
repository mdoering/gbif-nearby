import SwiftUI

struct GalleryTileView: View {
    let tile: GalleryTile

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            image
            LinearGradient(colors: [.clear, .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 56)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
            Text(tile.displayName)
                .font(.caption2.italic())
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color(.tertiarySystemFill))
    }

    @ViewBuilder
    private var image: some View {
        let url = ImageCacheURL.build(occurrenceKey: tile.occurrence.key,
                                      identifier: tile.identifier,
                                      size: .width(400))
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
            case .empty: Color(.tertiarySystemFill)
            case .failure:
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            @unknown default: Color(.tertiarySystemFill)
            }
        }
    }
}

#Preview {
    let occ = Occurrence(key: 1, datasetKey: nil, speciesKey: nil, species: "Bellis perennis",
                         scientificName: "Bellis perennis", acceptedScientificName: nil,
                         kingdom: nil, phylum: nil, class: nil, order: nil, family: nil, genus: nil,
                         decimalLatitude: 0, decimalLongitude: 0,
                         eventDate: nil, recordedBy: nil, basisOfRecord: nil,
                         media: [Media(type: "StillImage", format: nil, identifier: "x",
                                       title: nil, creator: nil, license: nil)])
    return GalleryTileView(tile: GalleryTile(occurrence: occ, mediaIndex: 0, identifier: "x"))
        .frame(width: 160, height: 160)
}
