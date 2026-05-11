# GBIF Nearby — Plan 4: Datasets tab

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Datasets tab — vicinity-aware by default with a "Search all GBIF datasets" opt-out toggle, search-as-you-type input, paginated rows, and a native detail screen with live records-within-radius count, copyable citation, and "Show on map / in gallery" handoffs through the existing `FocusFilterStore` + `TabSelectionStore`.

**Architecture:** A `DatasetsViewModel` (`@MainActor @Observable`) drives two modes:
- **Vicinity mode (default):** `/occurrence/search?geo_distance=...&kingdomKey=...&facet=datasetKey&facetLimit=100&facetMincount=1&limit=0` → enrich the top 30 buckets via `/dataset/{key}` concurrently. Search text filters the enriched rows client-side.
- **Global mode:** `/dataset/search?type=OCCURRENCE&q={search}&limit=20&offset={page*20}`. Standard pagination.

The mode toggle persists to `UserDefaults` via `SettingsStore`. The detail view fetches additional counts and renders the existing `Dataset` model. Tab handoffs reuse `FocusFilterStore.set(datasetKey:label:)` (already exists from Plan 1).

**Tech Stack:** Same as Plans 1–3.

---

## Spec

Implements the "Tab 4 — Datasets" section of [`docs/superpowers/specs/2026-05-11-gbif-nearby-ios-app-design.md`](../specs/2026-05-11-gbif-nearby-ios-app-design.md).

## File structure

| Path | Responsibility |
|---|---|
| `GBIFNearby/Features/Datasets/DatasetRowItem.swift` | Aggregate (Dataset + optional nearby count) |
| `GBIFNearby/Features/Datasets/DatasetsViewModel.swift` | Vicinity + global modes, search, debounced fetch |
| `GBIFNearby/Features/Datasets/DatasetRow.swift` | One row in the list |
| `GBIFNearby/Features/Datasets/DatasetsTabView.swift` | NavigationStack + header + toggle + searchable + list |
| `GBIFNearby/Features/Datasets/DatasetDetailView.swift` | Detail screen with stats + citation + handoffs |
| Modify: `GBIFNearby/Core/Settings/SettingsStore.swift` | Add `datasetsGlobal: Bool` (default false) |
| Modify: `GBIFNearby/App/RootTabView.swift` | Wire `DatasetsTabView()` in place of placeholder |
| Tests: `GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift` | Add `datasetsGlobal` tests |
| Tests: `GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift` | |

## Conventions

- **Build/test:**
  ```
  xcodegen generate
  xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
  ```
- **Baseline before Task 1:** 63 passing.
- **One commit per task.** TDD on stores and view-model logic; views validated via build + manual smoke.
- **No push** until controller pushes at end of plan.

---

## Task 1: Extend `SettingsStore` with `datasetsGlobal` (TDD)

**Files:**
- Modify: `GBIFNearby/Core/Settings/SettingsStore.swift`
- Modify: `GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift`

- [ ] **Step 1: Append failing tests**

Add to `SettingsStoreTests.swift` before the suite's closing `}`:
```swift

    @Test("datasetsGlobal default is false")
    func datasetsGlobalDefault() {
        let (s, _) = make()
        #expect(s.datasetsGlobal == false)
    }

    @Test("datasetsGlobal persists when set")
    func datasetsGlobalPersists() {
        let (s, d) = make()
        s.datasetsGlobal = true
        #expect(d.bool(forKey: "datasetsGlobal") == true)
    }

    @Test("datasetsGlobal restores from defaults")
    func datasetsGlobalRestores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set(true, forKey: "datasetsGlobal")
        let s = SettingsStore(defaults: suite)
        #expect(s.datasetsGlobal == true)
    }
```

- [ ] **Step 2: Run — expect compile failure (no `datasetsGlobal` property)**

- [ ] **Step 3: Implement**

In `GBIFNearby/Core/Settings/SettingsStore.swift`, add:
- A new static key constant `datasetsGlobalKey`
- A `datasetsGlobal: Bool` property with `didSet` that persists
- Restore in `init`

Final shape:
```swift
import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let vernacularLanguageKey = "vernacularLanguage"
    static let datasetsGlobalKey = "datasetsGlobal"
    private let defaults: UserDefaults

    var vernacularLanguage: String? {
        didSet {
            if let v = vernacularLanguage, v.isEmpty == false {
                defaults.set(v, forKey: Self.vernacularLanguageKey)
            } else {
                vernacularLanguage = nil
                defaults.removeObject(forKey: Self.vernacularLanguageKey)
            }
        }
    }

    var datasetsGlobal: Bool {
        didSet { defaults.set(datasetsGlobal, forKey: Self.datasetsGlobalKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.vernacularLanguage = defaults.string(forKey: Self.vernacularLanguageKey)
        self.datasetsGlobal = defaults.bool(forKey: Self.datasetsGlobalKey)
    }
}
```

- [ ] **Step 4: Run — expect 3 new pass; total 66**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Settings/SettingsStore.swift GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift
git commit -m "feat(core): add SettingsStore.datasetsGlobal toggle"
```

---

## Task 2: `DatasetRowItem` aggregate

**Files:**
- Create: `GBIFNearby/Features/Datasets/DatasetRowItem.swift`

(No automated tests — value type.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Datasets/DatasetRowItem.swift`
```swift
import Foundation

/// One row in the Datasets list. Combines a (possibly partial) Dataset with an optional
/// "records nearby" facet count for vicinity-aware mode.
struct DatasetRowItem: Identifiable, Sendable, Equatable {
    let key: String
    var title: String?
    var publisher: String?
    var type: String?
    var license: String?
    var nearbyCount: Int?

    var id: String { key }
}
```

- [ ] **Step 2: Build**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build build -quiet
```

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Datasets/DatasetRowItem.swift
git commit -m "feat(datasets): add DatasetRowItem aggregate"
```

---

## Task 3: `DatasetsViewModel.refreshVicinity` (TDD)

**Files:**
- Create: `GBIFNearby/Features/Datasets/DatasetsViewModel.swift`
- Test: `GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift`

- [ ] **Step 1: Failing tests**

File: `GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift`
```swift
import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("DatasetsViewModel — vicinity")
struct DatasetsViewModelTests {
    nonisolated private func bucket(_ key: String, _ count: Int) -> FacetBucket {
        FacetBucket(name: key, count: count)
    }

    nonisolated private func sampleDataset(key: String, title: String, publisher: String = "Org") -> Dataset {
        Dataset(key: key, title: title, type: "OCCURRENCE", license: "CC0_1_0",
                description: "Sample", publishingOrganizationKey: nil,
                publishingOrganizationTitle: publisher, citation: nil, contacts: nil)
    }

    @Test("refreshVicinity facets occurrence search, enriches top buckets")
    func refreshVicinity() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.kingdomKey == 6)
            #expect(q.facet == "datasetKey")
            #expect(q.facetLimit == 100)
            #expect(q.facetMincount == 1)
            #expect(q.limit == 0)
            return Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                        facets: [FacetGroup(field: "DATASET_KEY",
                                            counts: [self.bucket("ds-a", 50),
                                                     self.bucket("ds-b", 20)])])
        }
        await fake.setDataset { key in
            self.sampleDataset(key: key, title: "Dataset \(key)")
        }

        let vm = DatasetsViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, kingdomKey: 6, searchText: "")

        switch vm.rows {
        case .loaded(let items):
            #expect(items.count == 2)
            #expect(items[0].key == "ds-a")
            #expect(items[0].title == "Dataset ds-a")
            #expect(items[0].nearbyCount == 50)
        default: Issue.record("expected loaded, got \(vm.rows)")
        }
    }

    @Test("vicinity network error sets failed state")
    func vicinityError() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 500, message: nil) }
        let vm = DatasetsViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, searchText: "")
        if case .failed = vm.rows {} else { Issue.record("expected failed") }
    }
}
```

- [ ] **Step 2: regenerate & run — expect compile failure (`DatasetsViewModel` not in scope)**

- [ ] **Step 3: Implement** (vicinity-only first; global path is a stub returning empty until Task 4)

File: `GBIFNearby/Features/Datasets/DatasetsViewModel.swift`
```swift
import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class DatasetsViewModel {
    private let client: any GBIFClienting
    private let settings: SettingsStore
    private var task: Task<Void, Never>?

    var rows: Loading<[DatasetRowItem]> = .idle

    init(client: any GBIFClienting, settings: SettingsStore) {
        self.client = client
        self.settings = settings
    }

    /// Single entry point — chooses vicinity vs global based on `settings.datasetsGlobal`.
    /// Vicinity mode requires a coord (callers guard).
    func refresh(at coord: CLLocationCoordinate2D?, radiusKm: Double, kingdomKey: Int?, searchText: String) async {
        task?.cancel()
        rows = .loading
        if settings.datasetsGlobal {
            await runGlobal(searchText: searchText)
        } else {
            guard let coord else {
                rows = .loaded([])
                return
            }
            await runVicinity(coord: coord, radiusKm: radiusKm, kingdomKey: kingdomKey, searchText: searchText)
        }
    }

    // MARK: - Vicinity

    private func runVicinity(coord: CLLocationCoordinate2D, radiusKm: Double, kingdomKey: Int?, searchText: String) async {
        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.kingdomKey = kingdomKey
        q.facet = "datasetKey"
        q.facetLimit = 100
        q.facetMincount = 1
        q.limit = 0

        let captureClient = client
        let task = Task { [weak self] in
            do {
                let page = try await captureClient.occurrenceSearch(q)
                if Task.isCancelled { return }
                let buckets = page.facets?.first?.counts ?? []
                let head = Array(buckets.prefix(30))

                let enriched: [DatasetRowItem] = await withTaskGroup(of: (Int, DatasetRowItem).self,
                                                                     returning: [DatasetRowItem].self) { group in
                    for (idx, b) in head.enumerated() {
                        group.addTask { @Sendable in
                            var row = DatasetRowItem(key: b.name, nearbyCount: b.count)
                            if let ds = try? await captureClient.dataset(key: b.name) {
                                row.title = ds.title
                                row.publisher = ds.publishingOrganizationTitle
                                row.type = ds.type
                                row.license = ds.license
                            }
                            return (idx, row)
                        }
                    }
                    var result = head.enumerated().map { DatasetRowItem(key: $0.element.name, nearbyCount: $0.element.count) }
                    for await (idx, row) in group {
                        if idx < result.count { result[idx] = row }
                    }
                    return result
                }

                let filtered = Self.filterBySearch(rows: enriched, searchText: searchText)
                if Task.isCancelled { return }
                self?.rows = .loaded(filtered)
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self?.rows = .failed(error)
            } catch {
                self?.rows = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }

    // MARK: - Global (stub, expanded in Task 4)

    private func runGlobal(searchText: String) async {
        rows = .loaded([])
    }

    // MARK: - Filtering

    static func filterBySearch(rows: [DatasetRowItem], searchText: String) -> [DatasetRowItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return rows }
        return rows.filter { row in
            (row.title?.lowercased().contains(query) ?? false)
            || (row.publisher?.lowercased().contains(query) ?? false)
        }
    }
}
```

- [ ] **Step 4: run — 2 new pass; total 68**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Datasets/DatasetsViewModel.swift GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift
git commit -m "feat(datasets): add DatasetsViewModel vicinity mode"
```

---

## Task 4: Global mode (TDD)

**Files:**
- Modify: `GBIFNearby/Features/Datasets/DatasetsViewModel.swift`
- Modify: `GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift`

- [ ] **Step 1: Failing tests**

Append to `DatasetsViewModelTests.swift` before the closing `}`:
```swift

    @Test("global mode hits /dataset/search and maps to rows")
    func global() async {
        let fake = FakeGBIFClient()
        await fake.setDatasetSearch { query, page in
            #expect(query == "iNaturalist")
            #expect(page == 0)
            let ds = self.sampleDataset(key: "abc", title: "iNaturalist Research-grade")
            return Page(offset: 0, limit: 20, endOfRecords: true, count: 1,
                        results: [ds], facets: nil)
        }
        let settings = SettingsStore()
        settings.datasetsGlobal = true
        let vm = DatasetsViewModel(client: fake, settings: settings)
        await vm.refresh(at: nil, radiusKm: 5, kingdomKey: nil, searchText: "iNaturalist")
        switch vm.rows {
        case .loaded(let items):
            #expect(items.count == 1)
            #expect(items[0].key == "abc")
            #expect(items[0].title == "iNaturalist Research-grade")
            #expect(items[0].nearbyCount == nil)
        default: Issue.record("expected loaded, got \(vm.rows)")
        }
    }

    @Test("global mode with empty query passes nil to API")
    func globalEmptyQuery() async {
        let fake = FakeGBIFClient()
        await fake.setDatasetSearch { query, _ in
            #expect(query == nil || query == "")
            return Page(offset: 0, limit: 20, endOfRecords: true, count: 0, results: [], facets: nil)
        }
        let settings = SettingsStore()
        settings.datasetsGlobal = true
        let vm = DatasetsViewModel(client: fake, settings: settings)
        await vm.refresh(at: nil, radiusKm: 5, kingdomKey: nil, searchText: "")
        switch vm.rows {
        case .loaded(let items): #expect(items.isEmpty)
        default: Issue.record("expected loaded")
        }
    }
```

- [ ] **Step 2: run — expect compile/test failure**

- [ ] **Step 3: Implement** — replace the `runGlobal` stub:

```swift
    private func runGlobal(searchText: String) async {
        let captureClient = client
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: String? = q.isEmpty ? nil : q
        let task = Task { [weak self] in
            do {
                let page = try await captureClient.datasetSearch(query: query, page: 0)
                if Task.isCancelled { return }
                let rows = page.results.map { ds in
                    DatasetRowItem(key: ds.key,
                                   title: ds.title,
                                   publisher: ds.publishingOrganizationTitle,
                                   type: ds.type,
                                   license: ds.license,
                                   nearbyCount: nil)
                }
                self?.rows = .loaded(rows)
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self?.rows = .failed(error)
            } catch {
                self?.rows = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }
```

- [ ] **Step 4: run — 2 new pass; total 70**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Datasets/DatasetsViewModel.swift GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift
git commit -m "feat(datasets): add global mode (dataset/search)"
```

---

## Task 5: Client-side search filtering in vicinity (TDD)

**Files:**
- Modify: `GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift`

The filtering logic already exists in `DatasetsViewModel.filterBySearch`; this task adds a test asserting it's applied in vicinity mode end-to-end.

- [ ] **Step 1: Append test**

```swift

    @Test("vicinity search filters enriched rows by title (case-insensitive)")
    func vicinitySearchFilter() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "DATASET_KEY",
                                     counts: [self.bucket("a", 5), self.bucket("b", 3)])])
        }
        await fake.setDataset { key in
            self.sampleDataset(key: key, title: key == "a" ? "Birds of Berlin" : "Plants of Madrid")
        }
        let vm = DatasetsViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, searchText: "BERLIN")
        guard case .loaded(let items) = vm.rows else { Issue.record("expected loaded"); return }
        #expect(items.count == 1)
        #expect(items[0].key == "a")
    }
```

- [ ] **Step 2: Run — 1 new pass; total 71**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearbyTests/Features/Datasets/DatasetsViewModelTests.swift
git commit -m "test(datasets): vicinity search filters rows by title"
```

---

## Task 6: `DatasetRow` view

**Files:**
- Create: `GBIFNearby/Features/Datasets/DatasetRow.swift`

(Visual; manual verification.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Datasets/DatasetRow.swift`
```swift
import SwiftUI

struct DatasetRow: View {
    let item: DatasetRowItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.key)
                    .font(.body)
                    .lineLimit(2)
                Text(secondLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
    }

    private var secondLine: String {
        if let nearby = item.nearbyCount {
            let publisher = item.publisher ?? "Unknown publisher"
            return "\(publisher) · \(nearby) records nearby"
        } else {
            let type = item.type ?? "—"
            let license = item.license ?? ""
            return license.isEmpty ? type : "\(type) · \(license)"
        }
    }
}

#Preview {
    List {
        DatasetRow(item: DatasetRowItem(key: "a", title: "iNaturalist Research-grade Observations",
                                        publisher: "iNaturalist", type: "OCCURRENCE",
                                        license: "CC_BY_NC_4_0", nearbyCount: 123))
        DatasetRow(item: DatasetRowItem(key: "b", title: "Global Bird Survey",
                                        publisher: "BirdsOrg", type: "OCCURRENCE",
                                        license: "CC0_1_0", nearbyCount: nil))
    }
}
```

- [ ] **Step 2: Build**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Datasets/DatasetRow.swift
git commit -m "feat(datasets): add DatasetRow view"
```

---

## Task 7: `DatasetsTabView` with searchable + toggle

**Files:**
- Create: `GBIFNearby/Features/Datasets/DatasetsTabView.swift`

This task uses a temporary stub for `DatasetDetailView`, deleted in Task 8.

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Datasets/DatasetsTabView.swift`
```swift
import SwiftUI
import CoreLocation

struct DatasetsTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(SettingsStore.self) private var settings
    @Environment(\.gbifClient) private var client

    @State private var viewModel: DatasetsViewModel?
    @State private var searchText: String = ""
    @State private var searchDebouncer = AsyncDebouncer(delay: .milliseconds(300))
    @State private var filterDebouncer = AsyncDebouncer(delay: .milliseconds(400))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                modeToggle
                content
            }
            .navigationTitle("Datasets")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.datasetsGlobal ? "Search GBIF datasets" : "Filter nearby datasets")
            .task { ensureViewModel() }
            .onChange(of: searchText) { _, _ in scheduleSearch() }
            .onChange(of: settings.datasetsGlobal) { _, _ in scheduleFilter() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFilter() }
            .onChange(of: taxon.selected) { _, _ in scheduleFilter() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFilter() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFilter() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFilter() }
        }
    }

    private var modeToggle: some View {
        @Bindable var bindableSettings = settings
        return Toggle(isOn: $bindableSettings.datasetsGlobal) {
            Text("Search all GBIF datasets")
                .font(.footnote)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.rows ?? .idle {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let items):
            if items.isEmpty {
                empty
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            DatasetDetailViewStub(item: item)
                        } label: {
                            DatasetRow(item: item)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await fetch() }
            }
        case .failed(let err):
            VStack {
                ErrorBanner(message: err.userMessage) {
                    Task { await fetch() }
                }
                Spacer()
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
            Text(settings.datasetsGlobal
                 ? "No datasets match \"\(searchText)\"."
                 : "No datasets have records within \(String(format: "%.1f", radius.radiusKm)) km.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = DatasetsViewModel(client: client, settings: settings)
        }
        Task { await fetch() }
    }

    private func scheduleSearch() {
        Task { await searchDebouncer.schedule { await self.fetch() } }
    }

    private func scheduleFilter() {
        Task { await filterDebouncer.schedule { await self.fetch() } }
    }

    private func fetch() async {
        guard let vm = viewModel else { return }
        await vm.refresh(at: location.current,
                         radiusKm: radius.radiusKm,
                         kingdomKey: taxon.selected.taxonKey,
                         searchText: searchText)
    }
}

// Temporary stub — replaced in Task 8.
private struct DatasetDetailViewStub: View {
    let item: DatasetRowItem
    var body: some View {
        Text("Detail for \(item.title ?? item.key) (coming in Task 8)")
            .navigationTitle("Dataset")
            .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Build + test (71 still pass)**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Datasets/DatasetsTabView.swift
git commit -m "feat(datasets): add DatasetsTabView with searchable + mode toggle"
```

---

## Task 8: `DatasetDetailView` — header, stats, citation, contacts, handoffs

**Files:**
- Create: `GBIFNearby/Features/Datasets/DatasetDetailView.swift`
- Modify: `GBIFNearby/Features/Datasets/DatasetsTabView.swift` (drop stub)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Datasets/DatasetDetailView.swift`
```swift
import SwiftUI
import SafariServices
import UIKit

struct DatasetDetailView: View {
    let item: DatasetRowItem
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(FocusFilterStore.self) private var focus
    @Environment(TabSelectionStore.self) private var tabSelection
    @Environment(\.gbifClient) private var client

    @State private var dataset: Dataset?
    @State private var loadError: GBIFError?
    @State private var totalCount: Int?
    @State private var georefCount: Int?
    @State private var nearbyCount: Int?
    @State private var showSafari = false
    @State private var copiedCitation = false

    var body: some View {
        Form {
            Section {
                Text(dataset?.title ?? item.title ?? item.key)
                    .font(.headline)
                if let pub = dataset?.publishingOrganizationTitle ?? item.publisher {
                    Text(pub).foregroundStyle(.secondary).font(.subheadline)
                }
            }
            if let desc = dataset?.description, desc.isEmpty == false {
                Section("Description") {
                    Text(desc).font(.footnote).lineLimit(nil)
                }
            }
            Section("Counts") {
                statRow("Total records", value: totalCount)
                statRow("Georeferenced", value: georefCount)
                statRow("Within \(String(format: "%.1f", radius.radiusKm)) km", value: nearbyCount)
            }
            if let lic = dataset?.license ?? item.license {
                Section("License") {
                    Text(lic).font(.footnote)
                }
            }
            if let citation = dataset?.citation?.text, citation.isEmpty == false {
                Section("Citation") {
                    Text(citation).font(.footnote)
                    Button {
                        UIPasteboard.general.string = citation
                        copiedCitation = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            copiedCitation = false
                        }
                    } label: {
                        Label(copiedCitation ? "Copied!" : "Copy citation",
                              systemImage: copiedCitation ? "checkmark.circle.fill" : "doc.on.doc")
                    }
                }
            }
            if let contacts = dataset?.contacts, contacts.isEmpty == false {
                Section("Contacts") {
                    ForEach(Array(contacts.enumerated()), id: \.offset) { _, c in
                        contactRow(c)
                    }
                }
            }
            Section {
                Button {
                    showSafari = true
                } label: {
                    Label("View on GBIF.org", systemImage: "safari")
                }
                Button {
                    let label = dataset?.title ?? item.title ?? item.key
                    focus.set(datasetKey: item.key, label: label)
                    tabSelection.current = .map
                } label: {
                    Label("Show on map", systemImage: "map")
                }
                Button {
                    let label = dataset?.title ?? item.title ?? item.key
                    focus.set(datasetKey: item.key, label: label)
                    tabSelection.current = .gallery
                } label: {
                    Label("Show in gallery", systemImage: "photo.on.rectangle")
                }
            }
            if let err = loadError {
                Section {
                    Text(err.userMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Dataset")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: "https://www.gbif.org/dataset/\(item.key)")!)
                .ignoresSafeArea()
        }
        .task { await loadAll() }
        .onChange(of: radius.radiusKm) { _, _ in Task { await loadNearby() } }
        .onChange(of: location.current?.latitude) { _, _ in Task { await loadNearby() } }
        .onChange(of: location.current?.longitude) { _, _ in Task { await loadNearby() } }
    }

    @ViewBuilder
    private func statRow(_ label: String, value: Int?) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if let v = value {
                Text(v, format: .number).monospacedDigit()
            } else {
                ProgressView().controlSize(.mini)
            }
        }
    }

    @ViewBuilder
    private func contactRow(_ c: DatasetContact) -> some View {
        let name = [c.firstName, c.lastName].compactMap { $0 }.joined(separator: " ")
        let role = c.type ?? ""
        if let email = c.email?.first, let url = URL(string: "mailto:\(email)") {
            Link(destination: url) {
                VStack(alignment: .leading) {
                    Text(name).font(.body)
                    if role.isEmpty == false { Text(role).font(.caption).foregroundStyle(.secondary) }
                    Text(email).font(.caption).foregroundStyle(.tint)
                }
            }
        } else {
            VStack(alignment: .leading) {
                Text(name).font(.body)
                if role.isEmpty == false { Text(role).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private func loadAll() async {
        async let ds: Dataset? = (try? await client.dataset(key: item.key))
        async let total: Int? = {
            var q = OccurrenceQuery()
            q.datasetKey = item.key
            return try? await client.occurrenceCount(q)
        }()
        async let georef: Int? = {
            var q = OccurrenceQuery()
            q.datasetKey = item.key
            q.hasCoordinate = true
            return try? await client.occurrenceCount(q)
        }()
        let (d, t, g) = await (ds, total, georef)
        dataset = d
        totalCount = t
        georefCount = g
        await loadNearby()
    }

    private func loadNearby() async {
        guard let coord = location.current else { nearbyCount = nil; return }
        var q = OccurrenceQuery()
        q.datasetKey = item.key
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radius.radiusKm
        nearbyCount = try? await client.occurrenceCount(q)
    }
}
```

- [ ] **Step 2: Drop stub in `DatasetsTabView.swift`**

Delete `private struct DatasetDetailViewStub: View { ... }` at the bottom. In the `NavigationLink { ... } label: { ... }`, replace `DatasetDetailViewStub(item: item)` with `DatasetDetailView(item: item)`.

- [ ] **Step 3: Build + test (71 still pass)**

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Features/Datasets/DatasetDetailView.swift GBIFNearby/Features/Datasets/DatasetsTabView.swift
git commit -m "feat(datasets): add DatasetDetailView with stats, citation, contacts, handoffs"
```

---

## Task 9: Wire `DatasetsTabView` into `RootTabView`

**Files:**
- Modify: `GBIFNearby/App/RootTabView.swift`

- [ ] **Step 1: Replace placeholder**

In `GBIFNearby/App/RootTabView.swift`, replace:
```swift
placeholder("Datasets")
    .tabItem { Label("Datasets", systemImage: "tray.full") }
    .tag(Tab.datasets)
```
with:
```swift
DatasetsTabView()
    .tabItem { Label("Datasets", systemImage: "tray.full") }
    .tag(Tab.datasets)
```

- [ ] **Step 2: Build + test**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
```
Expect 71 tests pass.

- [ ] **Step 3: Best-effort simulator install + launch**

```bash
xcrun simctl boot 'iPhone 16e' 2>/dev/null || true
xcrun simctl uninstall booted org.gbif.nearby 2>/dev/null || true
xcrun simctl install booted "$(find build/Build/Products -name 'GBIFNearby.app' -print -quit)"
xcrun simctl launch booted org.gbif.nearby
```

Manual checks:
- Datasets tab: vicinity mode default → list of nearby-datasets with counts
- Toggle on → reverts to global mode; type "iNaturalist" → results
- Tap dataset → detail screen with counts, citation, "Copy citation" button, "Show on map" handoff that pre-filters Map tab via the focus chip

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/App/RootTabView.swift
git commit -m "feat(datasets): wire DatasetsTabView into RootTabView"
```

---

## Closeout

After Plan 4:

- 71 tests pass (8 new: 3 SettingsStore + 2 vicinity + 2 global + 1 search-filter).
- Datasets tab end-to-end functional in both modes.
- `DatasetDetailView` ships stats, copyable citation, mailto contacts, and the two filter-handoff buttons (Map / Gallery) that reuse the existing `FocusFilterStore` plumbing.

Push:
```bash
git push origin main
```

**Next plan:** `2026-05-11-gbif-nearby-plan-5-about-settings-polish.md` — About tab with static copy + Links, Settings UI (vernacular language picker, distance units, manual location row), Privacy manifest, IUCN status follow-up, app-icon polish, and any small bugs from the four feature plans.
