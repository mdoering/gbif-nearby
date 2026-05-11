import SwiftUI

struct RadiusHeader: View {
    @Environment(RadiusStore.self) private var radiusStore
    @Environment(TaxonFilterStore.self) private var taxonStore
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var radiusStore = radiusStore
        @Bindable var taxonStore = taxonStore
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
                        taxonStore.selected = k
                    } label: {
                        Label(k.displayLabel, systemImage: k.sfSymbol)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .padding(8)
                            .frame(minWidth: 44, minHeight: 32)
                            .background(taxonStore.selected == k ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground), in: Capsule())
                            .overlay(Capsule().stroke(taxonStore.selected == k ? Color.accentColor : .clear, lineWidth: 1.5))
                    }
                    .accessibilityLabel(k.displayLabel)
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

}

#Preview {
    RadiusHeader()
        .environment(RadiusStore())
        .environment(TaxonFilterStore())
        .environment(SettingsStore())
}
