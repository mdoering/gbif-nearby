import Foundation

enum Loading<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(GBIFError)

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
