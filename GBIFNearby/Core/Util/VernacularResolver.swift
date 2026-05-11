import Foundation

enum VernacularResolver {
    static func effectiveLanguage(userPreference: String?, deviceLanguageCode: String?) -> String {
        if let pref = userPreference, pref.isEmpty == false { return pref }
        if let code = deviceLanguageCode, code.isEmpty == false { return code }
        return "en"
    }

    static func choose(from names: [VernacularName], language: String) -> String? {
        if let hit = names.first(where: { $0.language == language }) {
            return hit.vernacularName
        }
        if language != "en", let en = names.first(where: { $0.language == "en" }) {
            return en.vernacularName
        }
        return nil
    }
}
