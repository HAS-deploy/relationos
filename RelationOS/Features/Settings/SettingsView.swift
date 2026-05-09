import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var contacts: ContactsStore
    @Environment(\.analytics) private var analytics

    @State private var showPaywall = false
    @State private var confirmingDelete = false
    @State private var didDeleteTrigger = 0

    var body: some View {
        Form {
            premiumSection
            displaySection
            privacySection
            aboutSection
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggeringFeature: .unlimitedContacts)
                .environmentObject(purchases)
        }
        .alert("Delete all data?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) {
                contacts.deleteAllData()
                settings.wipeAllSettings()
                analytics.track(.settingsDeleteAllData)
                didDeleteTrigger &+= 1
            }
        } message: {
            Text("This permanently removes every contact, note, tag, and reminder stored on this device.")
        }
        .hapticSuccess(trigger: didDeleteTrigger)
    }

    // MARK: - Sections

    @ViewBuilder
    private var premiumSection: some View {
        Section {
            if purchases.isPremium {
                Label("RelationOS Pro unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Try RelationOS Pro").font(.headline)
                            Text("14-day free trial. Cancel anytime.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                Button("Restore purchases") {
                    Task { await purchases.restorePurchases() }
                }
            }
        } header: {
            Text("Subscription")
        } footer: {
            if purchases.isPremium {
                Text("Manage subscription in iOS Settings → your Apple ID → Subscriptions.")
            } else {
                Text("Free tier: up to \(PricingConfig.freeContactCap) contacts. Pro unlocks unlimited contacts, the Daily Reconnect list (5 people every morning), and cooling-relationships highlighting in that view.")
            }
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(SettingsStore.Appearance.allCases) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
        }
    }

    private var privacySection: some View {
        Section {
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete all data", systemImage: "trash.fill")
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Removes every contact, note, tag, and reminder stored on this device. Required for App Store guideline 5.1.1(v).")
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy policy", destination: PricingConfig.privacyPolicyURL)
            Link("Terms of Use", destination: PricingConfig.termsOfUseURL)
            LabeledContent("Version", value: Bundle.main.marketingVersion)
        } header: {
            Text("About")
        } footer: {
            Text("RelationOS is a private, on-device personal CRM. Your data stays on your iPhone. Cloud sync is on the v1.1 roadmap.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Developer (DEBUG only)") {
            Button(purchases.isPremium ? "Disable premium (debug)" : "Enable premium (debug)") {
                purchases.debugTogglePremium()
            }
            Text("Contacts on file: \(contacts.contacts.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    #endif
}

private extension Bundle {
    var marketingVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
