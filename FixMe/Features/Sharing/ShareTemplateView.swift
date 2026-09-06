import SwiftUI
import Photos

/// Template + export-format picker for generating a share card from a day's progress.
struct ShareTemplateView: View {
    let journey: Journey
    let dayNumber: Int
    let completionPercent: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @State private var selectedTemplate: ShareTemplate = .dark
    @State private var paywallTrigger: PaywallTrigger?
    @State private var selectedFormat: ShareExportFormat = .instagramStory
    @State private var showActivitySheet = false
    @State private var renderedImage: UIImage?
    @State private var savedConfirmation = false

    private var habitNames: [String] {
        journey.habits.compactMap { habit in
            habit.completion(on: .now)?.state.isDone == true ? habit.name : nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: FMTheme.Spacing.lg) {
                ScrollView {
                    ShareCardView(
                        template: selectedTemplate,
                        dayNumber: dayNumber,
                        totalDays: journey.lengthInDays,
                        completionPercent: completionPercent,
                        streak: journey.habits.map { $0.currentStreak() }.max() ?? 0,
                        habitNames: habitNames.isEmpty ? ["Showing up"] : habitNames,
                        size: CGSize(width: 300, height: 300 * (selectedFormat.size.height / selectedFormat.size.width))
                    )
                    .shadow(color: FMTheme.Shadow.elevated, radius: 20, y: 10)
                    .padding(.top, FMTheme.Spacing.lg)
                }

                templatePicker
                formatPicker

                HStack(spacing: FMTheme.Spacing.sm) {
                    FMSecondaryButton(title: "Save to Photos") { saveToPhotos() }
                    FMPrimaryButton(title: "Share", icon: "square.and.arrow.up") { share() }
                }
                .padding(.horizontal, FMTheme.Spacing.lg)
                .padding(.bottom, FMTheme.Spacing.md)
            }
            .background(FMTheme.Colors.background)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showActivitySheet) {
                if let renderedImage { ActivityShareSheet(items: [renderedImage]) }
            }
            .alert("Saved to Photos", isPresented: $savedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .sheet(item: $paywallTrigger) { trigger in
                PaywallView(trigger: trigger)
            }
        }
    }

    private var templatePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FMTheme.Spacing.xs) {
                ForEach(ShareTemplate.allCases) { template in
                    let unlocked = services.premium.isTemplateUnlocked(template)
                    Button {
                        Haptics.selection()
                        guard unlocked else {
                            services.analytics.track(.featureGateHit(feature: PremiumFeature.premiumShareTemplates.rawValue))
                            paywallTrigger = .premiumTemplate
                            return
                        }
                        selectedTemplate = template
                    } label: {
                        HStack(spacing: 4) {
                            if !unlocked {
                                Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold))
                            }
                            Text(template.title).font(FMTheme.Typography.footnote)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selectedTemplate == template ? FMTheme.Colors.accent : FMTheme.Colors.surface)
                        .foregroundStyle(
                            selectedTemplate == template ? .white
                                : (unlocked ? FMTheme.Colors.textPrimary : FMTheme.Colors.textTertiary)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FMTheme.Spacing.lg)
        }
    }

    private var formatPicker: some View {
        Picker("Format", selection: $selectedFormat) {
            ForEach(ShareExportFormat.allCases) { format in
                Text(format.title).tag(format)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, FMTheme.Spacing.lg)
    }

    private func currentCard() -> ShareCardView {
        ShareCardView(
            template: selectedTemplate,
            dayNumber: dayNumber,
            totalDays: journey.lengthInDays,
            completionPercent: completionPercent,
            streak: journey.habits.map { $0.currentStreak() }.max() ?? 0,
            habitNames: habitNames.isEmpty ? ["Showing up"] : habitNames,
            size: selectedFormat.size
        )
    }

    private func share() {
        renderedImage = ShareCardRenderer.render(currentCard())
        showActivitySheet = true
        // Shared cards are the cheapest acquisition channel this app has — every one
        // carries the watermark, for free and paying users alike. Selling watermark
        // removal would quietly tax our own best growth loop.
        services.analytics.track(.shareCreated(template: selectedTemplate.rawValue))
        services.analytics.track(.shareExported(format: selectedFormat.rawValue))
    }

    private func saveToPhotos() {
        guard let image = ShareCardRenderer.render(currentCard()) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        Haptics.notify(.success)
        savedConfirmation = true
    }
}

#Preview {
    ShareTemplateView(journey: Journey(), dayNumber: 17, completionPercent: 82)
        .modelContainer(PreviewData.container)
}
