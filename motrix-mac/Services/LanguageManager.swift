import SwiftUI

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
        }
    }

    var locale: Locale {
        currentLanguage == "system" ? .current : Locale(identifier: currentLanguage)
    }

    var bundle: Bundle {
        guard currentLanguage != "system" else { return .main }
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let b = Bundle(path: path) else { return .main }
        return b
    }

    private init() {
        currentLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    }

    func localizedString(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle)
    }
}
