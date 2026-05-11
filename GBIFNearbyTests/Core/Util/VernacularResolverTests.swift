import Testing
import Foundation
@testable import GBIFNearby

@Suite("VernacularResolver")
struct VernacularResolverTests {
    @Test("user preference wins")
    func userPref() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: "fr", deviceLanguageCode: "de")
        #expect(lang == "fr")
    }

    @Test("device locale when no preference")
    func deviceLocale() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: nil, deviceLanguageCode: "de")
        #expect(lang == "de")
    }

    @Test("empty preference falls through to locale")
    func emptyPref() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: "", deviceLanguageCode: "es")
        #expect(lang == "es")
    }

    @Test("English fallback when nothing set")
    func englishFallback() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: nil, deviceLanguageCode: nil)
        #expect(lang == "en")
    }

    @Test("choose: first hit in preferred language")
    func chooseFirstHit() {
        let names = [
            VernacularName(vernacularName: "Buff-tailed bumblebee", language: "en"),
            VernacularName(vernacularName: "Erdhummel", language: "de"),
        ]
        let chosen = VernacularResolver.choose(from: names, language: "de")
        #expect(chosen == "Erdhummel")
    }

    @Test("choose: language miss falls back to English")
    func chooseFallbackEn() {
        let names = [
            VernacularName(vernacularName: "Buff-tailed bumblebee", language: "en"),
            VernacularName(vernacularName: "Erdhummel", language: "de"),
        ]
        let chosen = VernacularResolver.choose(from: names, language: "fr")
        #expect(chosen == "Buff-tailed bumblebee")
    }

    @Test("choose: nothing matches — returns nil")
    func chooseNoMatch() {
        let names = [VernacularName(vernacularName: "Erdhummel", language: "de")]
        let chosen = VernacularResolver.choose(from: names, language: "fr")
        #expect(chosen == nil)
    }

    @Test("choose: 2-letter request matches a 3-letter record (real GBIF shape)")
    func choose2vs3() {
        let names = [
            VernacularName(vernacularName: "Common House Sparrow", language: "eng"),
            VernacularName(vernacularName: "Haussperling", language: "deu"),
        ]
        #expect(VernacularResolver.choose(from: names, language: "de") == "Haussperling")
        #expect(VernacularResolver.choose(from: names, language: "fr") == "Common House Sparrow")
    }

    @Test("choose: 3-letter request matches a 2-letter record")
    func choose3vs2() {
        let names = [VernacularName(vernacularName: "Erdhummel", language: "de")]
        #expect(VernacularResolver.choose(from: names, language: "deu") == "Erdhummel")
    }
}
