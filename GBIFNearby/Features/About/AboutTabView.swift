import SwiftUI

struct AboutTabView: View {
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
                    Text("Settings come in Task 5.").foregroundStyle(.tertiary)
                }

                Section("Links") {
                    Text("Links come in Task 6.").foregroundStyle(.tertiary)
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
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview { AboutTabView() }
