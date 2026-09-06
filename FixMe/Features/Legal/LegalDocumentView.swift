import SwiftUI

/// Renders a legal document in-app.
///
/// Apple requires functional Terms and Privacy links on any subscription paywall; these
/// were previously empty buttons, which is an automatic rejection under Guideline 3.1.2.
struct LegalDocumentView: View {
    let document: LegalDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(FMTheme.Typography.display(28))
                            .foregroundStyle(FMTheme.Colors.textPrimary)
                        Text("Last updated \(document.lastUpdated)")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(FMTheme.Colors.textTertiary)
                    }

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                            Text(section.heading)
                                .font(FMTheme.Typography.headline)
                                .foregroundStyle(FMTheme.Colors.textPrimary)
                            Text(section.body)
                                .font(FMTheme.Typography.body)
                                .foregroundStyle(FMTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

#Preview("Privacy") { LegalDocumentView(document: .privacy) }
#Preview("Terms") { LegalDocumentView(document: .terms) }
