import SwiftUI

struct RootTabView: View {
    @Environment(TabSelectionStore.self) private var tabSelection

    var body: some View {
        @Bindable var tabSelection = tabSelection
        TabView(selection: $tabSelection.current) {
            MapTabView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)
            SpeciesTabView()
                .tabItem { Label("Species", systemImage: "leaf") }
                .tag(Tab.species)
            GalleryTabView()
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
                .tag(Tab.gallery)
            DatasetsTabView()
                .tabItem { Label("Datasets", systemImage: "tray.full") }
                .tag(Tab.datasets)
            placeholder("About")
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
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
        .environment(SettingsStore())
        .environment(TabSelectionStore())
}
