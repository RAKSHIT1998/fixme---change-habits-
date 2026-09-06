import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteDataConfirm = false
    @State private var showPaywall = false
    @State private var showReferral = false
    @State private var showHowTo = false
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var showDeletePhotosConfirm = false
    @State private var resultMessage: String?
    @State private var legalDocument: LegalDocument?

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            Form {
                if let user {
                    Section("You") {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Your name", text: Binding(
                                get: { user.name },
                                set: { newValue in
                                    user.name = newValue
                                    // Keep the name friends see in step with this one.
                                    services.peerIdentity.displayName =
                                        newValue.isEmpty ? PeerIdentityStore.placeholderName : newValue
                                    try? modelContext.save()
                                }
                            ))
                            .multilineTextAlignment(.trailing)
                        }
                        Text("Friends you pair with see this name.")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }

                    Section("Privacy") {
                        Picker("Who can see my progress", selection: Binding(
                            get: { user.privacyLevel },
                            set: { user.privacyLevel = $0; try? modelContext.save() }
                        )) {
                            ForEach(PrivacyLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                    }

                    if let settings = user.settings {
                        Section("Preferences") {
                            Toggle("Sound effects", isOn: Bindable(settings).soundEnabled)
                            Toggle("Haptics", isOn: Bindable(settings).hapticsEnabled)
                        }

                        Section("Connections") {
                            LabeledContent("Apple Health", value: settings.healthKitAuthorized ? "Connected" : "Not connected")
                            LabeledContent("Notifications", value: settings.notificationsAuthorized ? "Enabled" : "Disabled")
                        }
                    }
                }

                Section("Subscription") {
                    LabeledContent("Plan", value: services.premium.isPremium ? "Premium" : "Free")

                    if !services.premium.isPremium {
                        Button("Upgrade to Premium") { showPaywall = true }
                            .fontWeight(.semibold)
                        Text("Unlimited habits, unlimited AI verification, streak repair and every share template.")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    } else {
                        Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    }

                    Button("Restore purchases") {
                        Task { await services.subscriptions.restorePurchases() }
                    }
                }

                Section("Invite") {
                    Button("Invite a friend") { showReferral = true }
                    Text("You both get a free week of Premium when they start their 90 days.")
                        .font(FMTheme.Typography.footnote)
                        .foregroundStyle(FMTheme.Colors.textSecondary)
                }

                Section("Help") {
                    Button("How Fix Me works") { showHowTo = true }
                    Link("Contact support", destination: SupportLinks.email)
                    Link("Support & FAQ", destination: SupportLinks.website)
                    Button("Privacy Policy") { legalDocument = .privacy }
                    Button("Terms of Use") { legalDocument = .terms }
                }

                Section {
                    Button("Export my data") { exportData() }
                    Button("Delete my photos", role: .destructive) { showDeletePhotosConfirm = true }
                    Button("Delete my data", role: .destructive) { showDeleteDataConfirm = true }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Export writes a JSON file of your habits, history and journals. Your friend-signing key is never included — it stays in the Keychain.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(trigger: .settings) }
            .sheet(isPresented: $showHowTo) { HowToUseView() }
            .sheet(item: $legalDocument) { LegalDocumentView(document: $0) }
            .sheet(isPresented: $showExportSheet) {
                if let exportURL { ActivityShareSheet(items: [exportURL]) }
            }
            .confirmationDialog(
                "Delete every photo?",
                isPresented: $showDeletePhotosConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete photos", role: .destructive) { deletePhotos() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Verification photos and daily photos are removed from this device. Your habits, streaks and history are kept.")
            }
            .alert("Done", isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resultMessage ?? "")
            }
            .sheet(isPresented: $showReferral) { ReferralView(user: user) }
            .confirmationDialog("This deletes all your habits, journeys and history. This can't be undone.", isPresented: $showDeleteDataConfirm, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func exportData() {
        do {
            exportURL = try DataPrivacyService(modelContext: modelContext).exportToTemporaryFile()
            showExportSheet = true
        } catch {
            resultMessage = "Couldn't build the export. Your data is untouched."
        }
    }

    private func deletePhotos() {
        let removed = DataPrivacyService(modelContext: modelContext).deleteAllPhotos()
        Haptics.notify(.success)
        resultMessage = removed == 0
            ? "There were no photos to delete."
            : "\(removed) photo\(removed == 1 ? "" : "s") deleted."
    }

    private func deleteAllData() {
        for user in users { modelContext.delete(user) }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SettingsView().modelContainer(PreviewData.container)
}
