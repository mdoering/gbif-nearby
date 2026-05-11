# GBIF Nearby — Plan 3: Gallery tab

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Gallery tab — a paginated Pinterest-style grid of occurrence images within the current radius (filtered by kingdom + focus filter), with a full-bleed swipeable viewer that shows occurrence metadata and links out to GBIF.

**Architecture:** A `GalleryViewModel` (`@MainActor @Observable`) fetches pages of `/occurrence/search?mediaType=StillImage&geo_distance=...` and flattens each result's `media[]` into `GalleryTile`s keyed by `(occurrenceKey, mediaIndex)`. The view uses a `LazyVGrid` with adaptive columns; scroll-to-last-row triggers the next page (capped at 500 tiles). Tapping a tile pushes `OccurrenceDetailView`, which is a `TabView(.page)` of full-bleed images with metadata below — vernacular name is resolved lazily through the same `VernacularResolver` used by the Species tab.

**Tech Stack:** Same as Plans 1–2 — SwiftUI iOS 17+, Swift Testing, no third-party deps. All image URLs go through the GBIF image cache (`ImageCacheURL`).

---

## Spec

Implements the "Tab 3 — Gallery" section of [`docs/superpowers/specs/2026-05-11-gbif-nearby-ios-app-design.md`](../specs/2026-05-11-gbif-nearby-ios-app-design.md). Dataset-row tap from the detail view will land in Plan 4 (Datasets) — for now the dataset is shown as a static line.

## File structure

| Path | Responsibility |
|---|---|
| `GBIFNearby/Features/Gallery/GalleryTile.swift` | Tile aggregate (occurrence + media index + identifier) |
| `GBIFNearby/Features/Gallery/GalleryViewModel.swift` | Paginated fetch + flatten + cap |
| `GBIFNearby/Features/Gallery/GalleryTileView.swift` | One tile in the grid |
| `GBIFNearby/Features/Gallery/GalleryTabView.swift` | NavigationStack + header + grid + states |
| `GBIFNearby/Features/Gallery/OccurrenceDetailView.swift` | Full-bleed swipeable viewer + metadata |
| Modify: `GBIFNearby/App/RootTabView.swift` | Wire `GalleryTabView()` in place of the placeholder |
| Tests: `GBIFNearbyTests/Features/Gallery/GalleryViewModelTests.swift` | |

`OccurrenceDetailView` is intentionally a **new** view distinct from the existing `OccurrenceSheet` (Map tab modal). They serve different UX — the gallery viewer is full-screen with swipe between media; the map sheet is a small modal of facts.

## Conventions

- **Build/test:**
  ```
  xcodegen generate
  xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
  ```
- **Test baseline before Task 1:** 57 passing.
- **One commit per task.** TDD where there's logic (Tasks 2 and 3).
- **No push** until the controller pushes at end of plan.

---

## Task 1: `GalleryTile` aggregate model

**Files:**
- Create: `GBIFNearby/Features/Gallery/GalleryTile.swift`

(No automated tests — value type.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Gallery/GalleryTile.swift`
```swift
import Foundation

/// One tile in the Gallery grid — references a single still image of a single occurrence.
struct GalleryTile: Identifiable, Sendable, Equatable {
    let occurrence: Occurrence
    let mediaIndex: Int
    let identifier: String       // raw media `identifier` URL; passed to ImageCacheURL.build

    var id: String { "\(occurrence.key)_\(mediaIndex)" }
    var displayName: String { occurrence.scientificName ?? occurrence.species ?? "#\(occurrence.key)" }
}
```

- [ ] **Step 2: Build**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build build -quiet
```
Expect success.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Gallery/GalleryTile.swift
git commit -m "feat(gallery): add GalleryTile aggregate"
```

---

## Task 2: `GalleryViewModel.refresh` — first-page fetch (TDD)

**Files:**
- Create: `GBIFNearby/Features/Gallery/GalleryViewModel.swift`
- Test: `GBIFNearbyTests/Features/Gallery/GalleryViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

File: `GBIFNearbyTests/Features/Gallery/GalleryViewModelTests.swift`
```swift
import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("GalleryViewModel — refresh")
struct GalleryViewModelTests {
    nonisolated private func occurrence(key: Int, mediaIds: [String], species: String = "X") -> Occurrence {
        Occurrence(
            key: key, datasetKey: nil, speciesKey: nil, species: species,
            scientificName: species, acceptedScientificName: nil,
            kingdom: nil, phylum: nil, class: nil, order: nil, family: nil, genus: nil,
            decimalLatitude: 52.5, decimalLongitude: 13.4,
            eventDate: nil, recordedBy: nil, basisOfRecord: nil,
            media: mediaIds.map { Media(type: "StillImage", format: nil, identifier: $0,
                                        title: nil, creator: nil, license: nil) }
        )
    }

    @Test("refresh forwards filters and flattens media into tiles")
    func refresh() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.kingdomKey == 1)
            #expect(q.mediaType == "StillImage")
            #expect(q.hasCoordinate == true)
            #expect(q.limit == 50)
            #expect(q.offset == 0)
            return Page(offset: 0, limit: 50, endOfRecords: false, count: 100,
                        results: [
                            self.occurrence(key: 1, mediaIds: ["a", "b"], species: "Bombus"),
                            self.occurrence(key: 2, mediaIds: ["c"], species: "Apis"),
                            self.occurrence(key: 3, mediaIds: [], species: "Mantis"),
                        ],
                        facets: nil)
        }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, kingdomKey: 1, datasetKey: nil, speciesKey: nil)
        switch vm.tiles {
        case .loaded(let arr):
            #expect(arr.count == 3) // 2 from occ 1, 1 from occ 2, 0 from occ 3
            #expect(arr[0].occurrence.key == 1)
            #expect(arr[0].mediaIndex == 0)
            #expect(arr[0].identifier == "a")
            #expect(arr[1].occurrence.key == 1)
            #expect(arr[1].mediaIndex == 1)
            #expect(arr[2].occurrence.key == 2)
        default: Issue.record("expected loaded, got \(vm.tiles)")
        }
        #expect(vm.endOfResults == false)
    }

    @Test("skips occurrences with no still-image media; sets endOfResults from page flag")
    func endOfResults() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 50, endOfRecords: true, count: 0,
                 results: [self.occurrence(key: 9, mediaIds: [])],
                 facets: nil)
        }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        switch vm.tiles {
        case .loaded(let arr): #expect(arr.isEmpty)
        default: Issue.record("expected loaded empty")
        }
        #expect(vm.endOfResults == true)
    }

    @Test("network error sets failed state")
    func error() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 500, message: nil) }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        if case .failed = vm.tiles {} else { Issue.record("expected failed") }
    }
}
```

- [ ] **Step 2: Regenerate & run — expect compile failure (`GalleryViewModel` not in scope)**

- [ ] **Step 3: Implement**

File: `GBIFNearby/Features/Gallery/GalleryViewModel.swift`
```swift
import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class GalleryViewModel {
    static let pageSize = 50
    static let maxTiles = 500

    private let client: any GBIFClienting
    private var task: Task<Void, Never>?
    private var nextOffset: Int = 0
    private var lastQuery: OccurrenceQuery?

    var tiles: Loading<[GalleryTile]> = .idle
    var endOfResults: Bool = false
    var isLoadingMore: Bool = false

    init(client: any GBIFClienting) {
        self.client = client
    }

    /// Fetch the first page for the given filters. Replaces any in-flight task.
    func refresh(at coord: CLLocationCoordinate2D, radiusKm: Double,
                 kingdomKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        nextOffset = 0
        endOfResults = false
        tiles = .loading

        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.kingdomKey = kingdomKey
        q.datasetKey = datasetKey
        q.speciesKey = speciesKey
        q.mediaType = "StillImage"
        q.hasCoordinate = true
        q.limit = Self.pageSize
        q.offset = 0
        lastQuery = q

        let captureClient = client
        let task = Task { [weak self] in
            do {
                let page = try await captureClient.occurrenceSearch(q)
                if Task.isCancelled { return }
                guard let self else { return }
                let flat = Self.flatten(page: page)
                self.tiles = .loaded(flat)
                self.nextOffset = Self.pageSize
                self.endOfResults = page.endOfRecords ?? false
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self?.tiles = .failed(error)
            } catch {
                self?.tiles = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }

    /// Flattens a page of occurrences into one tile per StillImage media entry.
    static func flatten(page: Page<Occurrence>) -> [GalleryTile] {
        var out: [GalleryTile] = []
        for occ in page.results {
            guard let media = occ.media else { continue }
            for (idx, m) in media.enumerated() where m.type == "StillImage" {
                guard let id = m.identifier, id.isEmpty == false else { continue }
                out.append(GalleryTile(occurrence: occ, mediaIndex: idx, identifier: id))
            }
        }
        return out
    }
}
```

- [ ] **Step 4: Run — expect 3 new pass; total 60**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Gallery/GalleryViewModel.swift GBIFNearbyTests/Features/Gallery/GalleryViewModelTests.swift
git commit -m "feat(gallery): add GalleryViewModel.refresh + flatten"
```

---

## Task 3: `loadMoreIfNeeded(currentTileID:)` — pagination (TDD)

**Files:**
- Modify: `GBIFNearby/Features/Gallery/GalleryViewModel.swift`
- Modify: `GBIFNearbyTests/Features/Gallery/GalleryViewModelTests.swift`

- [ ] **Step 1: Append failing tests**

Append to `GalleryViewModelTests.swift`, before the suite's closing `}`:
```swift

    @Test("loadMoreIfNeeded fires when current tile is near the end")
    func loadMore() async {
        let fake = FakeGBIFClient()
        var callCount = 0
        await fake.setSearch { q in
            callCount += 1
            if q.offset == 0 {
                return Page(offset: 0, limit: 50, endOfRecords: false, count: 200,
                            results: (1...3).map { self.occurrence(key: $0, mediaIds: ["x\($0)"]) },
                            facets: nil)
            } else {
                #expect(q.offset == 50)
                return Page(offset: 50, limit: 50, endOfRecords: true, count: 200,
                            results: [self.occurrence(key: 99, mediaIds: ["y"])],
                            facets: nil)
            }
        }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        guard case .loaded(let first) = vm.tiles else { Issue.record("first page failed"); return }
        // Trigger on the LAST tile of page 1.
        await vm.loadMoreIfNeeded(currentTileID: first.last!.id)
        guard case .loaded(let combined) = vm.tiles else { Issue.record("after loadMore"); return }
        #expect(combined.count == 4)
        #expect(vm.endOfResults == true)
    }

    @Test("loadMoreIfNeeded is a no-op when not near the end")
    func loadMoreSkip() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            Page(offset: q.offset ?? 0, limit: 50, endOfRecords: false, count: 200,
                 results: (1...10).map { self.occurrence(key: $0, mediaIds: ["x\($0)"]) },
                 facets: nil)
        }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        guard case .loaded(let first) = vm.tiles else { Issue.record("first page failed"); return }
        // Trigger on the FIRST tile (far from the end).
        await vm.loadMoreIfNeeded(currentTileID: first.first!.id)
        guard case .loaded(let after) = vm.tiles else { Issue.record("expected loaded"); return }
        #expect(after.count == first.count) // no growth
    }

    @Test("loadMoreIfNeeded stops at maxTiles")
    func cap() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            Page(offset: q.offset ?? 0, limit: 50, endOfRecords: false, count: 10_000,
                 // Each page returns 50 occurrences with one media each → 50 tiles.
                 results: (1...50).map {
                     self.occurrence(key: ((q.offset ?? 0) * 100) + $0, mediaIds: ["m\($0)"])
                 },
                 facets: nil)
        }
        let vm = GalleryViewModel(client: fake)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        // Repeatedly trigger pagination from the last tile until cap is reached.
        for _ in 0..<20 {
            guard case .loaded(let arr) = vm.tiles, let lastID = arr.last?.id else { break }
            await vm.loadMoreIfNeeded(currentTileID: lastID)
            if vm.endOfResults || arr.count >= GalleryViewModel.maxTiles { break }
        }
        guard case .loaded(let final) = vm.tiles else { Issue.record("expected loaded"); return }
        #expect(final.count == GalleryViewModel.maxTiles)
        #expect(vm.endOfResults == true) // cap should set endOfResults to lock further loads
    }
```

- [ ] **Step 2: Run — expect compile failure (`loadMoreIfNeeded` missing)**

- [ ] **Step 3: Implement — append to `GalleryViewModel`**

Add to the `GalleryViewModel` class (before the closing `}` of the class, after `refresh`):
```swift
    /// Trigger pagination if the supplied tile is among the last 10 of the loaded list.
    /// Called from the view's `onAppear` of each tile.
    func loadMoreIfNeeded(currentTileID: String) async {
        guard isLoadingMore == false, endOfResults == false else { return }
        guard case .loaded(let current) = tiles else { return }
        guard current.count < Self.maxTiles else {
            endOfResults = true
            return
        }
        // Trigger only when the requested tile is in the trailing 10 tiles.
        guard let idx = current.firstIndex(where: { $0.id == currentTileID }),
              idx >= max(0, current.count - 10) else {
            return
        }
        guard var q = lastQuery else { return }
        q.offset = nextOffset
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await client.occurrenceSearch(q)
            if Task.isCancelled { return }
            let flat = Self.flatten(page: page)
            var combined = current + flat
            if combined.count > Self.maxTiles {
                combined = Array(combined.prefix(Self.maxTiles))
                endOfResults = true
            }
            tiles = .loaded(combined)
            nextOffset += Self.pageSize
            if endOfResults == false {
                endOfResults = page.endOfRecords ?? false
            }
        } catch {
            // Silent on pagination failure — leave existing tiles in place.
            // The user can pull to refresh.
        }
    }
```

- [ ] **Step 4: Run — expect 3 new pass; total 63**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Gallery/GalleryViewModel.swift GBIFNearbyTests/Features/Gallery/GalleryViewModelTests.swift
git commit -m "feat(gallery): paginate with loadMoreIfNeeded; cap at 500 tiles"
```

---

## Task 4: `GalleryTileView` visual tile

**Files:**
- Create: `GBIFNearby/Features/Gallery/GalleryTileView.swift`

(No automated tests — visual.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Gallery/GalleryTileView.swift`
```swift
import SwiftUI

struct GalleryTileView: View {
    let tile: GalleryTile

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            image
            LinearGradient(colors: [.clear, .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 56)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
            Text(tile.displayName)
                .font(.caption2.italic())
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color(.tertiarySystemFill))
    }

    @ViewBuilder
    private var image: some View {
        let url = ImageCacheURL.build(occurrenceKey: tile.occurrence.key,
                                      identifier: tile.identifier,
                                      size: .width(400))
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
            case .empty: Color(.tertiarySystemFill)
            case .failure:
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            @unknown default: Color(.tertiarySystemFill)
            }
        }
    }
}

#Preview {
    let occ = Occurrence(key: 1, datasetKey: nil, speciesKey: nil, species: "Bellis perennis",
                         scientificName: "Bellis perennis", acceptedScientificName: nil,
                         kingdom: nil, phylum: nil, class: nil, order: nil, family: nil, genus: nil,
                         decimalLatitude: 0, decimalLongitude: 0,
                         eventDate: nil, recordedBy: nil, basisOfRecord: nil,
                         media: [Media(type: "StillImage", format: nil, identifier: "x",
                                       title: nil, creator: nil, license: nil)])
    return GalleryTileView(tile: GalleryTile(occurrence: occ, mediaIndex: 0, identifier: "x"))
        .frame(width: 160, height: 160)
}
```

- [ ] **Step 2: Build**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Gallery/GalleryTileView.swift
git commit -m "feat(gallery): add GalleryTileView"
```

---

## Task 5: `GalleryTabView` — grid + states + debounce

**Files:**
- Create: `GBIFNearby/Features/Gallery/GalleryTabView.swift`

The grid uses an `Identifiable` selection that drives a navigation push to `OccurrenceDetailView`. Since `OccurrenceDetailView` is built in Task 6, this task uses a temporary inline stub.

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Gallery/GalleryTabView.swift`
```swift
import SwiftUI
import CoreLocation

struct GalleryTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(\.gbifClient) private var client

    @State private var viewModel: GalleryViewModel?
    @State private var debouncer = AsyncDebouncer(delay: .milliseconds(400))
    @State private var selectedTile: TileSelection?

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 110), spacing: 6)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                content
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .task { ensureViewModel() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFetch() }
            .onChange(of: taxon.selected) { _, _ in scheduleFetch() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFetch() }
            .onChange(of: focus.speciesKey) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFetch() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.tiles ?? .idle {
        case .idle, .loading:
            shimmer
        case .loaded(let items):
            if items.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, tile in
                            Button {
                                selectedTile = TileSelection(index: idx)
                            } label: {
                                GalleryTileView(tile: tile)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await viewModel?.loadMoreIfNeeded(currentTileID: tile.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    if let vm = viewModel, vm.isLoadingMore {
                        ProgressView().padding()
                    }
                }
                .refreshable { await refresh() }
                .navigationDestination(item: $selectedTile) { sel in
                    OccurrenceDetailViewStub(tiles: items, startIndex: sel.index)
                }
            }
        case .failed(let err):
            VStack {
                ErrorBanner(message: err.userMessage) {
                    Task { await refresh() }
                }
                Spacer()
            }
        }
    }

    private var shimmer: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .redacted(reason: .placeholder)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "photo.on.rectangle").font(.largeTitle).foregroundStyle(.secondary)
            Text("No photos within \(String(format: "%.1f", radius.radiusKm)) km.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Try a larger radius or different group.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = GalleryViewModel(client: client)
        }
        Task { await refresh() }
    }

    private func scheduleFetch() {
        Task { await debouncer.schedule { await self.refresh() } }
    }

    private func refresh() async {
        guard let center = location.current, let vm = viewModel else { return }
        await vm.refresh(at: center,
                         radiusKm: radius.radiusKm,
                         kingdomKey: taxon.selected.taxonKey,
                         datasetKey: focus.datasetKey,
                         speciesKey: focus.speciesKey)
    }
}

/// Wraps an index in an `Identifiable` shell for `.navigationDestination(item:)`.
struct TileSelection: Identifiable, Hashable {
    let index: Int
    var id: Int { index }
}

// Temporary stub — replaced by Task 6.
private struct OccurrenceDetailViewStub: View {
    let tiles: [GalleryTile]
    let startIndex: Int
    var body: some View {
        Text("Detail viewer for tile #\(startIndex) (coming in Task 6)")
            .navigationTitle("Occurrence")
            .navigationBarTitleDisplayMode(.inline)
    }
}
```

NOTE: `.navigationDestination(item:)` requires an `Identifiable` value. We wrap the index in a small `TileSelection` struct rather than extending `Int: Identifiable` module-wide.

- [ ] **Step 2: Build (no new tests)**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Gallery/GalleryTabView.swift
git commit -m "feat(gallery): add GalleryTabView with grid, pagination trigger, states"
```

---

## Task 6: `OccurrenceDetailView` — full-bleed swipeable viewer

**Files:**
- Create: `GBIFNearby/Features/Gallery/OccurrenceDetailView.swift`
- Modify: `GBIFNearby/Features/Gallery/GalleryTabView.swift` (remove temp stub)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Gallery/OccurrenceDetailView.swift`
```swift
import SwiftUI
import SafariServices

struct OccurrenceDetailView: View {
    let tiles: [GalleryTile]
    let startIndex: Int
    @Environment(SettingsStore.self) private var settings
    @Environment(\.gbifClient) private var client

    @State private var pageIndex: Int = 0
    @State private var vernacularByKey: [Int: String?] = [:]
    @State private var showSafari = false

    var body: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(tiles.enumerated()), id: \.element.id) { idx, tile in
                page(for: tile)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(currentTile?.displayName ?? "Occurrence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSafari = true
                } label: {
                    Image(systemName: "safari")
                }
                .disabled(currentTile == nil)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let tile = currentTile {
                SafariView(url: URL(string: "https://www.gbif.org/occurrence/\(tile.occurrence.key)")!)
                    .ignoresSafeArea()
            }
        }
        .onAppear { pageIndex = startIndex }
        .task(id: pageIndex) {
            await loadVernacularIfNeeded()
        }
    }

    private var currentTile: GalleryTile? {
        guard tiles.indices.contains(pageIndex) else { return nil }
        return tiles[pageIndex]
    }

    @ViewBuilder
    private func page(for tile: GalleryTile) -> some View {
        VStack(spacing: 0) {
            let url = ImageCacheURL.build(occurrenceKey: tile.occurrence.key,
                                          identifier: tile.identifier,
                                          size: .width(1200))
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .empty:
                    ProgressView().tint(.white)
                case .failure:
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
                @unknown default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)

            metadata(for: tile)
        }
    }

    @ViewBuilder
    private func metadata(for tile: GalleryTile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tile.displayName).font(.headline.italic()).lineLimit(2)
            if let speciesKey = tile.occurrence.speciesKey,
               let cached = vernacularByKey[speciesKey], let v = cached {
                Text(v).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let date = tile.occurrence.eventDate {
                    Label(date, systemImage: "calendar").labelStyle(.titleAndIcon)
                }
                if let recorder = tile.occurrence.recordedBy {
                    Label(recorder, systemImage: "person").lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let dsKey = tile.occurrence.datasetKey {
                Text("Dataset: \(dsKey)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let media = tile.occurrence.media,
               media.indices.contains(tile.mediaIndex),
               let license = media[tile.mediaIndex].license,
               license.isEmpty == false {
                Text(license).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
    }

    private func loadVernacularIfNeeded() async {
        guard let tile = currentTile,
              let speciesKey = tile.occurrence.speciesKey,
              vernacularByKey[speciesKey] == nil else { return }
        let lang = VernacularResolver.effectiveLanguage(
            userPreference: settings.vernacularLanguage,
            deviceLanguageCode: Locale.current.language.languageCode?.identifier
        )
        let names = (try? await client.vernacularNames(key: speciesKey, language: lang)) ?? []
        let chosen = VernacularResolver.choose(from: names, language: lang)
        if chosen == nil && lang != "en" {
            let en = (try? await client.vernacularNames(key: speciesKey, language: "en")) ?? []
            vernacularByKey[speciesKey] = VernacularResolver.choose(from: en, language: "en")
        } else {
            vernacularByKey[speciesKey] = chosen
        }
    }
}
```

- [ ] **Step 2: Remove stub from `GalleryTabView.swift`**

In `GalleryTabView.swift`:
- Delete the `private struct OccurrenceDetailViewStub: View { ... }` block at the bottom.
- In the `.navigationDestination(item: $selectedTileIndex)`, replace `OccurrenceDetailViewStub(tiles: items, startIndex: idx)` with `OccurrenceDetailView(tiles: items, startIndex: idx)`.

- [ ] **Step 3: Build + test (63 tests still pass)**

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Features/Gallery/OccurrenceDetailView.swift GBIFNearby/Features/Gallery/GalleryTabView.swift
git commit -m "feat(gallery): add full-bleed swipeable OccurrenceDetailView"
```

---

## Task 7: Wire `GalleryTabView` into `RootTabView`

**Files:**
- Modify: `GBIFNearby/App/RootTabView.swift`

- [ ] **Step 1: Replace placeholder**

Replace:
```swift
placeholder("Gallery")
    .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
    .tag(Tab.gallery)
```
with:
```swift
GalleryTabView()
    .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
    .tag(Tab.gallery)
```

- [ ] **Step 2: Build + test**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
```
Expect 63 tests pass.

- [ ] **Step 3: Best-effort simulator install + launch**

```bash
xcrun simctl boot 'iPhone 16e' 2>/dev/null || true
xcrun simctl uninstall booted org.gbif.nearby 2>/dev/null || true
xcrun simctl install booted "$(find build/Build/Products -name 'GBIFNearby.app' -print -quit)"
xcrun simctl launch booted org.gbif.nearby
```

Manual checks (if interactive):
- Tab to Gallery → shimmer briefly → grid of square tiles
- Scroll near bottom → next page loads
- Tap tile → full-bleed image, swipe left/right between media, Safari button opens GBIF page

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/App/RootTabView.swift
git commit -m "feat(gallery): wire GalleryTabView into RootTabView"
```

---

## Closeout

After Plan 3:

- 63 tests pass (6 new in GalleryViewModelTests).
- Gallery tab is end-to-end functional: paginated grid, scroll-to-load-more (capped at 500), full-bleed swipeable viewer, vernacular fallback in detail metadata, GBIF link.
- `OccurrenceDetailView` is a new file under `Features/Gallery/`; distinct from `Features/Map/OccurrenceSheet.swift` which keeps its modal pin-tap UX.

Push:
```bash
git push origin main
```

**Next plan:** `2026-05-11-gbif-nearby-plan-4-datasets-tab.md` — the Datasets tab with vicinity-aware mode, global mode toggle, search-as-you-type, dataset detail screen, and "Show on map / in gallery" handoffs that we already plumbed via `FocusFilterStore` + `TabSelectionStore`.
