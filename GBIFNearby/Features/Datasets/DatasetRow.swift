import SwiftUI

struct DatasetRow: View {
    let item: DatasetRowItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.key)
                    .font(.body)
                    .lineLimit(2)
                Text(secondLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
    }

    private var secondLine: String {
        if let nearby = item.nearbyCount {
            let publisher = item.publisher ?? "Unknown publisher"
            return "\(publisher) · \(nearby) records nearby"
        } else {
            let type = item.type ?? "—"
            let license = item.license ?? ""
            return license.isEmpty ? type : "\(type) · \(license)"
        }
    }
}

#Preview {
    List {
        DatasetRow(item: DatasetRowItem(key: "a", title: "iNaturalist Research-grade Observations",
                                        publisher: "iNaturalist", type: "OCCURRENCE",
                                        license: "CC_BY_NC_4_0", nearbyCount: 123))
        DatasetRow(item: DatasetRowItem(key: "b", title: "Global Bird Survey",
                                        publisher: "BirdsOrg", type: "OCCURRENCE",
                                        license: "CC0_1_0", nearbyCount: nil))
    }
}
