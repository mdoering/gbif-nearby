import SwiftUI
import UIKit
import CoreLocation

struct AboutTabView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationStore.self) private var location
    @State private var safariURL: SafariLink?

    var body: some View {
        NavigationStack {
            Form {
                Section("About this app") {
                    Text("GBIF Nearby shows GBIF biodiversity data recorded around your current location. Drag the radius slider in the header to change the search distance, and tap the kingdom chips to focus on Animals, Plants, or Fungi.")
                        .font(.footnote)
                    Text("Browse occurrences on the Map, a ranked Species list with vernacular names, a photo Gallery, and the underlying Datasets — all live from the GBIF API.")
                        .font(.footnote)
                }

                Section("About GBIF") {
                    Text("GBIF — the Global Biodiversity Information Facility — is an international network and data infrastructure funded by the world's governments and aimed at providing anyone, anywhere, open access to data about all types of life on Earth.")
                        .font(.footnote)
                }

                Section("Settings") {
                    @Bindable var settings = settings

                    Picker("Vernacular language", selection: Binding(
                        get: { settings.vernacularLanguage ?? "" },
                        set: { settings.vernacularLanguage = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Use device language").tag("")
                        Divider()
                        ForEach(Self.languageOptions, id: \.code) { opt in
                            Text(opt.label).tag(opt.code)
                        }
                    }

                    Picker("Distance unit", selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    locationRow
                }

                Section("Links") {
                    linkRow(title: "Open GBIF.org", urlString: "https://www.gbif.org")
                    linkRow(title: "GBIF Occurrence search", urlString: "https://www.gbif.org/occurrence/search")
                    linkRow(title: "GBIF API documentation", urlString: "https://techdocs.gbif.org/en/openapi/")
                    linkRow(title: "GBIF data use guidelines", urlString: "https://www.gbif.org/citation-guidelines")
                }

                Section("App") {
                    HStack {
                        Text("Version").foregroundStyle(.secondary)
                        Spacer()
                        Text(appVersion).monospacedDigit()
                    }
                    HStack {
                        Text("Build").foregroundStyle(.secondary)
                        Spacer()
                        Text(appBuild).monospacedDigit()
                    }
                    Text("Data: GBIF.org · Map tiles: GBIF & Apple Maps")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $safariURL) { link in
                SafariView(url: link.url).ignoresSafeArea()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private struct SafariLink: Identifiable, Hashable {
        let url: URL
        var id: URL { url }
    }

    private struct LanguageOption: Hashable {
        let code: String
        let label: String
    }

    private static let languageOptions: [LanguageOption] = [
        .init(code: "en", label: "English"),
        .init(code: "de", label: "Deutsch"),
        .init(code: "fr", label: "Français"),
        .init(code: "es", label: "Español"),
        .init(code: "pt", label: "Português"),
        .init(code: "it", label: "Italiano"),
        .init(code: "nl", label: "Nederlands"),
        .init(code: "sv", label: "Svenska"),
        .init(code: "ja", label: "日本語"),
        .init(code: "zh", label: "中文"),
        .init(code: "ru", label: "Русский"),
    ]

    @ViewBuilder
    private var locationRow: some View {
        switch location.source {
        case .manual:
            HStack {
                Label("Manual pin", systemImage: "mappin.circle.fill")
                Spacer()
                Button("Clear") { location.clearManual() }
                    .foregroundStyle(.tint)
            }
        case .device:
            HStack {
                Text("Location").foregroundStyle(.secondary)
                Spacer()
                Text(authStatusText).foregroundStyle(.secondary).font(.footnote)
            }
            if location.authStatus == .denied || location.authStatus == .restricted {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            }
        }
    }

    @ViewBuilder
    private func linkRow(title: String, urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Button {
                safariURL = SafariLink(url: url)
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "safari").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var authStatusText: String {
        switch location.authStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorizedWhenInUse: return "While using"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    AboutTabView()
        .environment(SettingsStore())
        .environment(LocationStore())
}
