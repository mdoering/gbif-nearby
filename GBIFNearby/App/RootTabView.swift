import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Text("Map").tabItem { Label("Map", systemImage: "map") }
            Text("Species").tabItem { Label("Species", systemImage: "leaf") }
            Text("Gallery").tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
            Text("Datasets").tabItem { Label("Datasets", systemImage: "tray.full") }
            Text("About").tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

#Preview { RootTabView() }
