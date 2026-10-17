import Foundation

enum AppearanceMode: String {
    case system, dark, light

    static func load(from defaults: UserDefaults = .standard) -> AppearanceMode {
        AppearanceMode(rawValue: defaults.string(forKey: "appearanceMode") ?? "") ?? .system
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: "appearanceMode")
    }

    func next(systemIsDark: Bool) -> AppearanceMode {
        let systemAppearance: AppearanceMode = systemIsDark ? .dark : .light
        if self == .system { return systemIsDark ? .light : .dark }
        return self == systemAppearance ? .system : systemAppearance
    }

    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}
