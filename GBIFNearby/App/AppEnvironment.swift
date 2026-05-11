import SwiftUI

@MainActor
struct AppEnvironment {
    let locationStore: LocationStore
    let radiusStore: RadiusStore
    let taxonStore: TaxonFilterStore
    let focusStore: FocusFilterStore
    let client: any GBIFClienting

    static func production() -> AppEnvironment {
        AppEnvironment(
            locationStore: LocationStore(),
            radiusStore: RadiusStore(),
            taxonStore: TaxonFilterStore(),
            focusStore: FocusFilterStore(),
            client: GBIFClient()
        )
    }
}
