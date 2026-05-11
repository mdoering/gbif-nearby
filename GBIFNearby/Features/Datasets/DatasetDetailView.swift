import SwiftUI
import SafariServices
import UIKit

struct DatasetDetailView: View {
    let item: DatasetRowItem
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(FocusFilterStore.self) private var focus
    @Environment(TabSelectionStore.self) private var tabSelection
    @Environment(\.gbifClient) private var client

    @State private var dataset: Dataset?
    @State private var loadError: GBIFError?
    @State private var totalCount: Int?
    @State private var georefCount: Int?
    @State private var nearbyCount: Int?
    @State private var showSafari = false
    @State private var copiedCitation = false

    var body: some View {
        Form {
            Section {
                Text(dataset?.title ?? item.title ?? item.key)
                    .font(.headline)
                if let pub = dataset?.publishingOrganizationTitle ?? item.publisher {
                    Text(pub).foregroundStyle(.secondary).font(.subheadline)
                }
            }
            if let desc = dataset?.description, desc.isEmpty == false {
                Section("Description") {
                    Text(desc).font(.footnote).lineLimit(nil)
                }
            }
            Section("Counts") {
                statRow("Total records", value: totalCount)
                statRow("Georeferenced", value: georefCount)
                statRow("Within \(String(format: "%.1f", radius.radiusKm)) km", value: nearbyCount)
            }
            if let lic = dataset?.license ?? item.license {
                Section("License") {
                    Text(lic).font(.footnote)
                }
            }
            if let citation = dataset?.citation?.text, citation.isEmpty == false {
                Section("Citation") {
                    Text(citation).font(.footnote)
                    Button {
                        UIPasteboard.general.string = citation
                        copiedCitation = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            copiedCitation = false
                        }
                    } label: {
                        Label(copiedCitation ? "Copied!" : "Copy citation",
                              systemImage: copiedCitation ? "checkmark.circle.fill" : "doc.on.doc")
                    }
                }
            }
            if let contacts = dataset?.contacts, contacts.isEmpty == false {
                Section("Contacts") {
                    ForEach(Array(contacts.enumerated()), id: \.offset) { _, c in
                        contactRow(c)
                    }
                }
            }
            Section {
                Button {
                    showSafari = true
                } label: {
                    Label("View on GBIF.org", systemImage: "safari")
                }
                Button {
                    let label = dataset?.title ?? item.title ?? item.key
                    focus.set(datasetKey: item.key, label: label)
                    tabSelection.current = .map
                } label: {
                    Label("Show on map", systemImage: "map")
                }
                Button {
                    let label = dataset?.title ?? item.title ?? item.key
                    focus.set(datasetKey: item.key, label: label)
                    tabSelection.current = .gallery
                } label: {
                    Label("Show in gallery", systemImage: "photo.on.rectangle")
                }
            }
            if let err = loadError {
                Section {
                    Text(err.userMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Dataset")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: "https://www.gbif.org/dataset/\(item.key)")!)
                .ignoresSafeArea()
        }
        .task { await loadAll() }
        .onChange(of: radius.radiusKm) { _, _ in Task { await loadNearby() } }
        .onChange(of: location.current?.latitude) { _, _ in Task { await loadNearby() } }
        .onChange(of: location.current?.longitude) { _, _ in Task { await loadNearby() } }
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

    @ViewBuilder
    private func contactRow(_ c: DatasetContact) -> some View {
        let name = [c.firstName, c.lastName].compactMap { $0 }.joined(separator: " ")
        let role = c.type ?? ""
        if let email = c.email?.first, let url = URL(string: "mailto:\(email)") {
            Link(destination: url) {
                VStack(alignment: .leading) {
                    Text(name).font(.body)
                    if role.isEmpty == false { Text(role).font(.caption).foregroundStyle(.secondary) }
                    Text(email).font(.caption).foregroundStyle(.tint)
                }
            }
        } else {
            VStack(alignment: .leading) {
                Text(name).font(.body)
                if role.isEmpty == false { Text(role).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private func loadAll() async {
        async let ds: Dataset? = (try? await client.dataset(key: item.key))
        async let total: Int? = {
            var q = OccurrenceQuery()
            q.datasetKey = item.key
            return try? await client.occurrenceCount(q)
        }()
        async let georef: Int? = {
            var q = OccurrenceQuery()
            q.datasetKey = item.key
            q.hasCoordinate = true
            return try? await client.occurrenceCount(q)
        }()
        let (d, t, g) = await (ds, total, georef)
        dataset = d
        totalCount = t
        georefCount = g
        await loadNearby()
    }

    private func loadNearby() async {
        guard let coord = location.current else { nearbyCount = nil; return }
        var q = OccurrenceQuery()
        q.datasetKey = item.key
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radius.radiusKm
        nearbyCount = try? await client.occurrenceCount(q)
    }
}
