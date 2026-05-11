import SwiftUI

struct SpeciesListRow: View {
    let item: SpeciesRowItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.scientificName ?? item.canonicalName ?? "#\(item.speciesKey)")
                    .font(.body.italic())
                    .lineLimit(1)
                if let vernacular = item.vernacularName {
                    Text(vernacular).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(item.count, format: .number)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let t = item.thumbnail {
            let url = ImageCacheURL.build(occurrenceKey: t.occurrenceKey,
                                          identifier: t.mediaIdentifier,
                                          size: .square(100))
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                case .empty: placeholder
                case .failure: placeholder
                @unknown default: placeholder
                }
            }
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            kingdomGlyph.foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var kingdomGlyph: some View {
        switch item.kingdom?.lowercased() {
        case "animalia":
            Image(systemName: "pawprint.fill")
        case "plantae":
            Image(systemName: "leaf.fill")
        case "fungi":
            Image("Mushroom").renderingMode(.template).resizable().scaledToFit().frame(width: 20, height: 20)
        default:
            Image(systemName: "circle.dotted")
        }
    }
}

#Preview {
    List {
        SpeciesListRow(item: SpeciesRowItem(speciesKey: 1, count: 42,
                                            scientificName: "Bellis perennis",
                                            canonicalName: "Bellis perennis",
                                            authorship: "L., 1758",
                                            vernacularName: "Common daisy",
                                            kingdom: "Plantae",
                                            thumbnail: nil))
    }
}
