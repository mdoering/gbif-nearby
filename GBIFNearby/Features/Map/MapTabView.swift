import SwiftUI
import CoreLocation
import MapKit

struct MapTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(\.gbifClient) private var client

    @State private var viewModel: MapViewModel?
    @State private var selectedOccurrence: Occurrence?
    @State private var pinDebouncer = AsyncDebouncer(delay: .milliseconds(400))
    @State private var regionDebouncer = AsyncDebouncer(delay: .milliseconds(500))
    @State private var pinFetchEnabled = false
    @State private var mapType: MKMapType = .standard
    @State private var recenterID: Int = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map
                VStack(spacing: 0) {
                    RadiusHeader()
                    FocusFilterChip()
                    if case .failed(let err) = viewModel?.pins ?? .idle {
                        ErrorBanner(message: err.userMessage) {
                            Task { await fetchIfReady() }
                        }
                    }
                }
                mapControls
            }
            .sheet(item: $selectedOccurrence) { occ in
                OccurrenceSheet(occurrence: occ)
            }
            .task { ensureViewModel() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFetch() }
            .onChange(of: taxon.selected) { _, _ in scheduleFetch() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFetch() }
            .onChange(of: focus.speciesKey) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFetch() }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var map: some View {
        if let center = location.current {
            GBIFMapView(
                center: center,
                radiusKm: radius.radiusKm,
                taxonKey: taxon.selected.taxonKey,
                datasetKey: focus.datasetKey,
                speciesKey: focus.speciesKey,
                pins: viewModel?.pins.value ?? [],
                mapType: mapType,
                recenterID: recenterID,
                onPinTap: { selectedOccurrence = $0 },
                onLongPress: { coord in location.setManual(coord) },
                onRegionChange: { region in
                    pinFetchEnabled = region.span.latitudeDelta < 0.2 // ~22 km height, ~31 km diagonal
                    scheduleRegionFetch()
                }
            )
        } else {
            LocationPrompt()
        }
    }

    private var mapControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Menu {
                        Picker("Map Type", selection: $mapType) {
                            Label("Standard", systemImage: "map").tag(MKMapType.standard)
                            Label("Satellite", systemImage: "globe.americas.fill").tag(MKMapType.satellite)
                            Label("Hybrid", systemImage: "globe.americas").tag(MKMapType.hybrid)
                        }
                    } label: {
                        mapButtonLabel(systemName: "square.3.layers.3d")
                    }
                    .accessibilityLabel("Map type")

                    Button {
                        if location.source == .manual { location.clearManual() }
                        recenterID += 1
                    } label: {
                        mapButtonLabel(systemName: "location.fill")
                    }
                    .accessibilityLabel("Recenter on me")
                }
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
        }
        .allowsHitTesting(location.current != nil)
        .opacity(location.current != nil ? 1 : 0)
    }

    private func mapButtonLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = MapViewModel(client: client)
        }
        Task { await fetchIfReady() }
    }

    private func scheduleFetch() {
        Task {
            await pinDebouncer.schedule { await self.fetchIfReady() }
        }
    }

    private func scheduleRegionFetch() {
        Task {
            await regionDebouncer.schedule { await self.fetchIfReady() }
        }
    }

    private func fetchIfReady() async {
        guard let center = location.current, let vm = viewModel else { return }
        if pinFetchEnabled == false {
            vm.clearPins()
            return
        }
        await vm.fetchPins(at: center,
                           radiusKm: radius.radiusKm,
                           kingdomKey: taxon.selected.taxonKey,
                           datasetKey: focus.datasetKey,
                           speciesKey: focus.speciesKey)
    }
}

private struct LocationPrompt: View {
    @Environment(LocationStore.self) private var location
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.circle").font(.system(size: 56)).foregroundStyle(.secondary)
            switch location.authStatus {
            case .notDetermined:
                Text("GBIF Nearby uses your location to show records around you.")
                    .multilineTextAlignment(.center)
                Button("Allow location") { location.requestAuthorization() }
                    .buttonStyle(.borderedProminent)
            case .denied, .restricted:
                Text("Location access is off. You can long-press the map to drop a pin instead, or enable location in Settings.")
                    .multilineTextAlignment(.center)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            default:
                ProgressView("Finding your location…")
            }
            Spacer()
        }
        .padding(24)
    }
}
