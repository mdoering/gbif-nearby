import Foundation

actor AsyncDebouncer {
    private let delay: Duration
    private var task: Task<Void, Never>?

    init(delay: Duration) {
        self.delay = delay
    }

    func schedule(_ action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            if Task.isCancelled { return }
            await action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
