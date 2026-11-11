import Combine
import Foundation
import ServiceManagement

enum Theme: String, CaseIterable {
    case system, light, dark
    var title: String { L("theme.\(rawValue)") }
}

enum BarMode: String, CaseIterable {
    case swap, swapAndMemory, icon
    var title: String {
        switch self {
        case .swap: return L("bar.swap")
        case .swapAndMemory: return L("bar.swapmem")
        case .icon: return L("bar.icon")
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var theme: Theme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    @Published var barMode: BarMode { didSet { defaults.set(barMode.rawValue, forKey: "barMode") } }
    /// "" = follow the system language.
    @Published var language: String {
        didSet {
            defaults.set(language, forKey: "language")
            L10n.override = language.isEmpty ? nil : language
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Swappy: launch at login failed: \(error.localizedDescription)")
                let lang = defaults.string(forKey: "language") ?? ""
        language = lang
        L10n.override = lang.isEmpty ? nil : lang
        launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private init() {
        theme = Theme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        barMode = BarMode(rawValue: defaults.string(forKey: "barMode") ?? "") ?? .swap
        let lang = defaults.string(forKey: "language") ?? ""
        language = lang
        L10n.override = lang.isEmpty ? nil : lang
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
