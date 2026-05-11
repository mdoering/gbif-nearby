import Foundation

enum VernacularResolver {
    static func effectiveLanguage(userPreference: String?, deviceLanguageCode: String?) -> String {
        if let pref = userPreference, pref.isEmpty == false { return pref }
        if let code = deviceLanguageCode, code.isEmpty == false { return code }
        return "en"
    }

    /// Pick the best vernacular name for the requested language, falling back to English.
    ///
    /// GBIF's `vernacularNames` endpoint returns 3-letter ISO 639-2/T codes (`eng`,
    /// `deu`, `fra`, …) while the rest of the app — settings, the device locale, the
    /// language picker — works in 2-letter ISO 639-1 (`en`, `de`, `fr`). We accept
    /// either form here and compare both, so the right name surfaces regardless of
    /// which form the caller passed and which form a particular `VernacularName`
    /// record happens to carry.
    static func choose(from names: [VernacularName], language: String) -> String? {
        let request = languageVariants(for: language)
        if let hit = names.first(where: { matches($0.language, request) }) {
            return hit.vernacularName
        }
        let english = languageVariants(for: "en")
        if request.isDisjoint(with: english),
           let en = names.first(where: { matches($0.language, english) }) {
            return en.vernacularName
        }
        return nil
    }

    private static func matches(_ candidate: String?, _ variants: Set<String>) -> Bool {
        guard let c = candidate, c.isEmpty == false else { return false }
        return variants.contains(c.lowercased())
    }

    /// Build the set { 2-letter, 3-letter } for a language code, so we can match
    /// regardless of which form the data uses. `Locale.Language` does the conversion.
    private static func languageVariants(for code: String) -> Set<String> {
        let lower = code.lowercased()
        var out: Set<String> = [lower]
        let language = Locale.Language(identifier: lower)
        if let alpha3 = language.languageCode?.identifier(.alpha3), alpha3.isEmpty == false {
            out.insert(alpha3.lowercased())
        }
        if let alpha2 = language.languageCode?.identifier(.alpha2), alpha2.isEmpty == false {
            out.insert(alpha2.lowercased())
        }
        return out
    }
}
