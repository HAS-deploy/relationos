import Foundation
import SwiftUI
import Combine

/// Lightweight settings backed by UserDefaults.
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let appearance = "relationos.settings.appearance"
        // Portfolio analytics keys (also lives under UserDefaults.standard).
        // Listed here so wipeAllSettings() can clear them for the
        // "Delete all data" 5.1.1(v)-style action.
        static let analyticsOptedOut = "portfolio.analytics.opted_out"
        static let analyticsFirstLaunchAt = "portfolio.analytics.first_launch_at"
        static let analyticsIdentified = "portfolio.analytics.identified"
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self { case .system: return "System"; case .light: return "Light"; case .dark: return "Dark" }
        }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let appearanceRaw = defaults.string(forKey: Keys.appearance) ?? Appearance.system.rawValue
        self.appearance = Appearance(rawValue: appearanceRaw) ?? .system
    }

    var forcedColorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Wipe all known UserDefaults keys this app owns. Called from Settings →
    /// Delete all data after the contacts store has been cleared. Also
    /// clears the portfolio.analytics.* keys (always on UserDefaults.standard,
    /// regardless of which suite SettingsStore was initialized with) so the
    /// reset-to-first-launch path is complete.
    func wipeAllSettings() {
        defaults.removeObject(forKey: Keys.appearance)
        // Reset published values to defaults so the UI updates immediately.
        self.appearance = .system

        // Portfolio analytics opt-out / identity / first-launch keys are
        // always written to .standard (see PortfolioAnalytics.swift). Wipe
        // them there explicitly so "Delete all data" really deletes
        // everything.
        let std = UserDefaults.standard
        std.removeObject(forKey: Keys.analyticsOptedOut)
        std.removeObject(forKey: Keys.analyticsFirstLaunchAt)
        std.removeObject(forKey: Keys.analyticsIdentified)
    }
}
