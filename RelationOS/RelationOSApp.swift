import SwiftUI

@main
struct RelationOSApp: App {
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var contacts = ContactsStore()
    @StateObject private var callObserver = CallObserver()
    @Environment(\.scenePhase) private var scenePhase
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
                .environmentObject(callObserver)
                .environment(\.analytics, analytics)
                .environment(\.reminders, reminders)
                .task {
                    await purchases.start()
                    callObserver.start()
                }
                .onChange(of: scenePhase) { phase in
                    // Tick the install-trial day counter when the user
                    // returns from background, so the banner crosses midnight
                    // correctly without a full relaunch.
                    if phase == .active { purchases.refreshTrialState() }
                }
                .preferredColorScheme(settings.forcedColorScheme)
        }
    }
}
