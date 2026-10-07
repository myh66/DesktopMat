import Foundation

/// Native preferences store visual choices only; no Finder file metadata.
@MainActor
final class RugPreferences {
    private let defaults: UserDefaults
    private let visibilityKey = "rugVisible"
    private let styleKey = "rugStyle"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [visibilityKey: true, styleKey: RugStyle.ningxia.rawValue])
    }

    var isVisible: Bool {
        get { defaults.bool(forKey: visibilityKey) }
        set { defaults.set(newValue, forKey: visibilityKey) }
    }

    var style: RugStyle {
        get { RugStyle(rawValue: defaults.string(forKey: styleKey) ?? "") ?? .ningxia }
        set { defaults.set(newValue.rawValue, forKey: styleKey) }
    }
}
