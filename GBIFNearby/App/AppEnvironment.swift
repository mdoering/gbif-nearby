import SwiftUI

@MainActor
struct AppEnvironment {
    let locationStore: LocationStore
    let radiusStore: RadiusStore
    let taxonStore: TaxonFilterStore
    let focusStore: FocusFilterStore
    let settingsStore: SettingsStore
    let tabSelectionStore: TabSelectionStore
    let client: any GBIFClienting

    static func production() -> AppEnvironment {
        AppEnvironment(
            locationStore: LocationStore(),
            radiusStore: RadiusStore(),
            taxonStore: TaxonFilterStore(),
            focusStore: FocusFilterStore(),
            settingsStore: SettingsStore(),
            tabSelectionStore: TabSelectionStore(),
            client: GBIFClient()
        )
    }
}
