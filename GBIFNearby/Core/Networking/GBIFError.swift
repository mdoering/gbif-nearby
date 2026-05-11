import Foundation

enum GBIFError: Error, Sendable {
    case network(URLError)
    case http(status: Int, message: String?)
    case decoding(DecodingError)
    case cancelled

    var userMessage: String {
        switch self {
        case .network: return "No network connection."
        case .http(let status, let m): return m ?? "Server error (\(status))."
        case .decoding: return "Unexpected response from server."
        case .cancelled: return "Cancelled."
        }
    }
}
