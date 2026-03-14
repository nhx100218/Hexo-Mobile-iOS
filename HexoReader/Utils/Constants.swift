import Foundation

enum Constants {
    static let appName = "HexoReader"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }
}
