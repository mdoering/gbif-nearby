import SwiftUI

/// Async image with pinch-to-zoom, drag-to-pan (only while zoomed), and double-tap
/// to toggle between 1× and 2×. When at scale 1 the drag gesture is not installed,
/// so the parent (e.g. a paged TabView) keeps its own swipe handling.
struct ZoomableImage: View {
    let url: URL
    let minScale: CGFloat
    let maxScale: CGFloat

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(url: URL, minScale: CGFloat = 1, maxScale: CGFloat = 5) {
        self.url = url
        self.minScale = minScale
        self.maxScale = maxScale
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnify)
                    .simultaneousGesture(scale > 1.0001 ? pan : nil)
                    .onTapGesture(count: 2) { toggleZoom() }
            case .empty:
                ProgressView().tint(.white)
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.5))
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = lastScale * value
                scale = min(maxScale, max(minScale, next))
            }
            .onEnded { _ in
                if scale < 1.05 {
                    reset()
                } else {
                    lastScale = scale
                }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if scale > 1.05 {
                reset()
            } else {
                scale = 2
                lastScale = 2
            }
        }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
