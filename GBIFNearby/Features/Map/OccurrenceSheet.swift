import SwiftUI
import SafariServices

struct OccurrenceSheet: View {
    let occurrence: Occurrence
    @State private var showSafari = false

    var body: some View {
        NavigationStack {
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
                }
                Section {
                    Button("View on GBIF.org") { showSafari = true }
                }
            }
            .navigationTitle("Occurrence #\(occurrence.key)")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSafari) {
                SafariView(url: URL(string: "https://www.gbif.org/occurrence/\(occurrence.key)")!)
                    .ignoresSafeArea()
            }
        }
        .presentationDetents([.medium, .large])
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
