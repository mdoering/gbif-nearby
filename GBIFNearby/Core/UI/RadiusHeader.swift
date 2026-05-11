import SwiftUI

struct RadiusHeader: View {
    @Environment(RadiusStore.self) private var radiusStore
    @Environment(TaxonFilterStore.self) private var taxonStore
    @Environment(SettingsStore.self) private var settings

    @State private var showTaxonSearch = false

    var body: some View {
        @Bindable var radiusStore = radiusStore
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Radius").font(.caption).foregroundStyle(.secondary)
                Slider(value: $radiusStore.radiusKm, in: RadiusStore.minValue...RadiusStore.maxValue)
                Text(DistanceFormatter.format(km: radiusStore.radiusKm, unit: settings.distanceUnit))
                    .font(.caption.monospacedDigit())
                    .frame(width: 64, alignment: .trailing)
            }
            HStack(spacing: 8) {
                ForEach(KingdomFilter.allCases, id: \.self) { k in
                    Button {
                        // Toggle: tapping the selected chip clears it.
                        taxonStore.selected = (taxonStore.selected == k) ? nil : k
                    } label: {
                        kingdomIcon(k)
                            .font(.title3)
                            .padding(8)
                            .frame(minWidth: 44, minHeight: 32)
                            .background(taxonStore.selected == k ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground), in: Capsule())
                            .overlay(Capsule().stroke(taxonStore.selected == k ? Color.accentColor : .clear, lineWidth: 1.5))
                    }
                    .accessibilityLabel(k.displayLabel)
                    .buttonStyle(.plain)
                }

                taxonSearchControl

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .sheet(isPresented: $showTaxonSearch) {
            TaxonSearchSheet()
        }
    }

    @ViewBuilder
    private func kingdomIcon(_ k: KingdomFilter) -> some View {
        switch k.icon {
        case .sfSymbol(let name):
            Image(systemName: name)
        case .emoji(let glyph):
            Text(glyph)
        }
    }

    @ViewBuilder
    private var taxonSearchControl: some View {
        if let override = taxonStore.taxonOverride {
            // Active selection — show as a removable chip.
            Button {
                showTaxonSearch = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").font(.caption2)
                    Text(override.scientificName)
                        .font(.caption.italic())
                        .lineLimit(1)
                    Button {
                        taxonStore.taxonOverride = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.2), in: Capsule())
                .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1.5))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Taxon filter: \(override.displayLabel). Tap to change, ⨯ to clear.")
        } else {
            Button {
                showTaxonSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .padding(8)
                    .frame(minWidth: 44, minHeight: 32)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .accessibilityLabel("Search taxon")
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    RadiusHeader()
        .environment(RadiusStore())
        .environment(TaxonFilterStore())
        .environment(SettingsStore())
}
