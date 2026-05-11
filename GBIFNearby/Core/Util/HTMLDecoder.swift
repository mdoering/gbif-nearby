import Foundation

enum HTMLDecoder {
    /// Best-effort decode of HTML-bearing text (entities + tags) into readable plain text.
    /// GBIF dataset descriptions frequently come back as HTML — `<p>`, `&amp;`, `&#39;`, &c.
    /// Returns the original string unchanged if decoding fails.
    @MainActor
    static func plainText(from html: String) -> String {
        guard let data = html.data(using: .utf8) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return html
        }
        return attr.string
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
