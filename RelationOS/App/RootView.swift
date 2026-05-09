import SwiftUI

struct RootView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @State private var selection: Tab = RootView.initialTab()
    @State private var paywallTrigger: PremiumFeature?

    enum Tab: Hashable { case contacts, reconnect, settings }

    static func initialTab() -> Tab {
        #if DEBUG
        let value = UserDefaults.standard.string(forKey: "RELATIONOS_INITIAL_TAB")
            ?? ProcessInfo.processInfo.environment["RELATIONOS_INITIAL_TAB"]
        switch value {
        case "reconnect": return .reconnect
        case "settings": return .settings
        default: return .contacts
        }
        #else
        return .contacts
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ContactsListView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("Contacts", systemImage: "person.2.fill") }
            .tag(Tab.contacts)

            NavigationStack {
                DailyReconnectView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("Reconnect", systemImage: "arrow.uturn.right.circle") }
            .tag(Tab.reconnect)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(Theme.accent)
        .sheet(item: $paywallTrigger) { feature in
            PaywallView(triggeringFeature: feature)
                .environmentObject(purchases)
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "RELATIONOS_SHOW_PAYWALL") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    paywallTrigger = .dailyReconnect
                }
            }
            #endif
        }
    }
}
