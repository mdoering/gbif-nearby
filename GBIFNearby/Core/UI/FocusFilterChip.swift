import SwiftUI

struct FocusFilterChip: View {
    @Environment(FocusFilterStore.self) private var focus

    var body: some View {
        if focus.isActive, let label = focus.label {
            HStack(spacing: 6) {
                Text("Filter:").font(.caption).foregroundStyle(.secondary)
                Text(label).font(.caption).lineLimit(1)
                Button {
                    focus.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: Capsule())
            .padding(.horizontal, 16).padding(.vertical, 4)
        }
    }
}

#Preview {
    let store = FocusFilterStore()
    store.set(datasetKey: "abc", label: "iNaturalist Research-grade")
    return FocusFilterChip().environment(store)
}
