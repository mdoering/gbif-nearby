import SwiftUI

@main
struct GBIFNearbyApp: App {
    @State private var env = AppEnvironment.production()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(env.locationStore)
                .environment(env.radiusStore)
                .environment(env.taxonStore)
                .environment(env.focusStore)
                .environment(\.gbifClient, env.client)
                .task { env.locationStore.requestAuthorization() }
        }
    }
}

private struct GBIFClientKey: EnvironmentKey {
    static let defaultValue: any GBIFClienting = GBIFClient()
}

extension EnvironmentValues {
    var gbifClient: any GBIFClienting {
        get { self[GBIFClientKey.self] }
        set { self[GBIFClientKey.self] = newValue }
    }
}
