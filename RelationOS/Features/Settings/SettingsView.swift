import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var contacts: ContactsStore
    @Environment(\.analytics) private var analytics

    @State private var showPaywall = false
    @State private var confirmingDelete = false
    @State private var didDeleteTrigger = 0

    // DEBUG-only: a launch argument `RELATIONOS_SCREENSHOT_PAYWALL=1`
    // (env var or `-RELATIONOS_SCREENSHOT_PAYWALL 1`) auto-opens the
    // paywall on Settings appear. Used by the screenshot harness.
    // Stripped from Release builds via #if DEBUG.
    #if DEBUG
    private var shouldAutoShowPaywall: Bool {
        ProcessInfo.processInfo.environment["RELATIONOS_SCREENSHOT_PAYWALL"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-RELATIONOS_SCREENSHOT_PAYWALL")
    }
    #endif

    var body: some View {
        Form {
            premiumSection
            displaySection
            privacySection
            aboutSection
            #if DEBUG
            if ProcessInfo.processInfo.environment["RELATIONOS_HIDE_DEBUG_SECTION"] != "1" {
                debugSection
            }
            #endif
        }
        .navigationTitle("Settings")
        #if DEBUG
        .onAppear {
            if shouldAutoShowPaywall { showPaywall = true }
        }
        #endif
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
            if purchases.hasActiveSubscription {
                Label("RelationOS Pro unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
            } else if purchases.isInIntroTrial {
                Button { showPaywall = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pro free, \(purchases.introTrialDaysRemaining) day\(purchases.introTrialDaysRemaining == 1 ? "" : "s") left")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                            Text("Subscribe any time to keep Pro after the trial ends.")
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
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Subscribe to RelationOS Pro").font(.headline)
                            Text("Cancel anytime in iOS Settings → Subscriptions.")
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
            if purchases.hasActiveSubscription {
                Text("Manage subscription in iOS Settings → your Apple ID → Subscriptions.")
            } else if purchases.isInIntroTrial {
                Text("Your 14-day Pro trial started on first launch — no card, no commitment. After it ends, RelationOS reverts to the free tier (up to \(PricingConfig.freeContactCap) contacts) unless you subscribe.")
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
            Text("Removes every contact, note, tag, reminder, and logged interaction stored on this device. This action cannot be undone.")
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
            Text("RelationOS keeps your contacts, notes, and reminders on your iPhone. Cross-device sync is on the roadmap and off by default.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Developer (DEBUG only)") {
            Button(purchases.hasActiveSubscription ? "Cancel sub (debug)" : "Force sub (debug)") {
                purchases.debugTogglePremium()
            }
            Button("Rewind trial to day 13") { purchases.debugRewindTrial(daysIn: 13) }
            Button("Force trial expired") { purchases.debugForceTrialExpired() }
            Button("Reset trial (re-grant 14 days)") { purchases.debugResetTrial() }
            Text("isPremium=\(purchases.isPremium ? "Y" : "N")  sub=\(purchases.hasActiveSubscription ? "Y" : "N")  trial=\(purchases.isInIntroTrial ? "Y(\(purchases.introTrialDaysRemaining)d)" : "N")")
                .font(.caption).foregroundStyle(.secondary)
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
