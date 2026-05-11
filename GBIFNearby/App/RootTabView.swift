import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            MapTabView()
                .tabItem { Label("Map", systemImage: "map") }
            placeholder("Species")
                .tabItem { Label("Species", systemImage: "leaf") }
            placeholder("Gallery")
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
            placeholder("Datasets")
                .tabItem { Label("Datasets", systemImage: "tray.full") }
            placeholder("About")
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }

    private func placeholder(_ label: String) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                Spacer()
                Text(label).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

#Preview {
    RootTabView()
        .environment(LocationStore())
        .environment(RadiusStore())
        .environment(TaxonFilterStore())
        .environment(FocusFilterStore())
}
