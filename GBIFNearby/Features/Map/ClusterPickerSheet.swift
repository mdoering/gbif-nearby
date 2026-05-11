import SwiftUI

/// Picker shown when the user taps a map cluster whose members all sit at the same
/// coordinate — at that point no amount of zooming will separate them visually, so we
/// surface a list and let the user drill into each record.
struct ClusterPickerSheet: View {
    let occurrences: [Occurrence]

    var body: some View {
        NavigationStack {
            List(occurrences) { occ in
                NavigationLink {
                    OccurrenceDetailContent(occurrence: occ)
                } label: {
                    ClusterRow(occurrence: occ)
                }
            }
            .listStyle(.plain)
            .navigationTitle("\(occurrences.count) records here")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ClusterRow: View {
    let occurrence: Occurrence

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(occurrence.scientificName ?? occurrence.species ?? "#\(occurrence.key)")
                .font(.body.italic())
                .lineLimit(2)
            HStack(spacing: 8) {
                if let date = occurrence.eventDate {
                    Label(date, systemImage: "calendar")
                }
                if let recorder = occurrence.recordedBy {
                    Label(recorder, systemImage: "person").lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
