import SwiftUI

@main
struct RelationOSApp: App {
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var contacts = ContactsStore()
    @StateObject private var mail = MailCoordinator()
    // NOTE: CallObserver is intentionally NOT instantiated at launch.
    // CXCallObserver registers a system-wide audio/call delegate, which a
    // contacts app shouldn't hold without a visible reason. The
    // LogInteractionSheet creates and starts the observer locally only
    // when the user opens it — so RelationOS observes call state only
    // for the duration of the user's logging session.
    @Environment(\.scenePhase) private var scenePhase
    private let analytics: AnalyticsService = ConsoleAnalytics()
    private let reminders = ReminderManager()

    init() {
        // PortfolioAnalytics wires PostHog with privacy-strict config
        // (`personProfiles=.never`, no screen-views, no lifecycle events,
        // no session replay). Events leave the device tagged with a
        // random per-install ID — no contact data, no name/email/phone.
        // App Privacy nutrition answers + PrivacyInfo.xcprivacy are the
        // source of truth for what's collected.
        PortfolioAnalytics.shared.start(appName: "relationos")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchases)
                .environmentObject(settings)
                .environmentObject(contacts)
                .environmentObject(mail)
                .environment(\.analytics, analytics)
                .environment(\.reminders, reminders)
                .task { await purchases.start() }
                .onChange(of: scenePhase) { phase in
                    // Tick the install-trial day counter when the user
                    // returns from background, so the banner crosses midnight
                    // correctly without a full relaunch.
                    if phase == .active {
                        purchases.refreshTrialState()
                        purchases.syncAnalyticsEntitlement()
                        PortfolioAnalytics.shared.track(PortfolioEvent.appForegrounded)
                    }
                }
                .preferredColorScheme(settings.forcedColorScheme)
        }
    }
}
