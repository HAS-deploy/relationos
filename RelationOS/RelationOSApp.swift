import SwiftUI

@main
struct RelationOSApp: App {
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var contacts = ContactsStore()
    private let analytics: AnalyticsService = ConsoleAnalytics()
    private let reminders = ReminderManager()

    init() {
        // PortfolioAnalytics is a no-op when PostHog is not linked (the project
        // does not depend on PostHog) — the start() call here is harmless and
        // keeps the call-site uniform with other apps in the portfolio. No
        // network traffic is generated. See Core/Analytics/PortfolioAnalytics.swift.
        PortfolioAnalytics.shared.start(appName: "relationos")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchases)
                .environmentObject(settings)
                .environmentObject(contacts)
                .environment(\.analytics, analytics)
                .environment(\.reminders, reminders)
                .task { await purchases.start() }
                .preferredColorScheme(settings.forcedColorScheme)
        }
    }
}
