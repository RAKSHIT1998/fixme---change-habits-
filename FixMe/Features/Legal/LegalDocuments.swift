import Foundation

/// Terms and privacy text.
///
/// Written to describe what this app actually does — every claim here is checkable
/// against the code. It is **not** legal advice and hasn't been reviewed by a lawyer;
/// treat it as an accurate first draft to hand to one. App Store Connect also requires a
/// privacy policy at a public URL, so this text needs hosting somewhere as well.
enum LegalDocument: String, Identifiable, CaseIterable {
    case privacy, terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms of Use"
        }
    }

    var lastUpdated: String { "September 2026" }

    var sections: [LegalSection] {
        switch self {
        case .privacy: return Self.privacySections
        case .terms: return Self.termsSections
        }
    }

    // MARK: - Privacy

    private static let privacySections: [LegalSection] = [
        LegalSection(
            heading: "The short version",
            body: """
            Fix Me has no accounts and no servers. Your habits, photos, journals, streaks \
            and friends are stored on your device. We cannot read them, because they never \
            reach us.
            """
        ),
        LegalSection(
            heading: "What stays on your device",
            body: """
            Everything you create in the app: habits and their history, quit-tracking data \
            including relapses and cravings, journal entries, daily and verification photos, \
            badges, XP, alarms, and your friend list.

            Deleting the app deletes all of it. Settings also offers "Delete my photos" and \
            "Delete my data" at any time.
            """
        ),
        LegalSection(
            heading: "Photos and AI verification",
            body: """
            When you use PROVE IT, the photo is analysed on your device using Apple's Vision \
            framework. The image is not uploaded, and no third party sees it.

            Analysis is approximate. It can detect things like a face with open eyes, or \
            readable text on a page — it cannot confirm what you actually did, and the app \
            never claims otherwise.

            Verification photos are kept on your device so you can review them, and can be \
            deleted individually or all at once.
            """
        ),
        LegalSection(
            heading: "Health data",
            body: """
            If you grant permission, Fix Me reads step count, active energy, exercise time, \
            walking and running distance, workouts and sleep from Apple Health, purely to \
            complete matching habits automatically.

            Health data is read on your device, is never transmitted, and is never used for \
            advertising or shared with anyone. You can decline or revoke this at any time in \
            the Health app — habits then fall back to manual completion and everything else \
            keeps working.
            """
        ),
        LegalSection(
            heading: "Friends and peer-to-peer sharing",
            body: """
            Adding a friend exchanges a display name and a public key, either directly \
            between two nearby devices or through an invite link you send yourself.

            Progress updates you choose to send are signed by your device and travel \
            directly to your friend's device, or inside a link you share through your own \
            messaging app. There is no server in between and no copy kept anywhere else. \
            Only the fields you tick are included.
            """
        ),
        LegalSection(
            heading: "Contacts",
            body: """
            If you choose to invite someone from Contacts, iOS shows its own contact picker \
            and hands back only the person you tap. Fix Me does not request Contacts \
            permission and never reads your address book.
            """
        ),
        LegalSection(
            heading: "Purchases",
            body: """
            Subscriptions are processed by Apple. Fix Me never sees your payment details. We \
            receive only whether an active entitlement exists, so premium features can unlock.
            """
        ),
        LegalSection(
            heading: "Analytics and tracking",
            body: """
            This version of Fix Me includes no third-party analytics, advertising, or \
            tracking SDKs, and does not use the Advertising Identifier. If that ever changes, \
            this policy will be updated before it ships.
            """
        ),
        LegalSection(
            heading: "Children",
            body: """
            Fix Me is not directed at children under 13, and includes content about quitting \
            smoking and alcohol intended for adults.
            """
        ),
        LegalSection(
            heading: "Contact",
            body: """
            Questions about this policy, or about data held on your device, can be sent to \
            rakshitbargotra@gmail.com. There is no account for us to look up — everything \
            the app knows about you is on your own device.
            """
        ),
    ]

    // MARK: - Terms

    private static let termsSections: [LegalSection] = [
        LegalSection(
            heading: "What Fix Me is",
            body: """
            Fix Me is a habit-tracking app. It helps you record and stick to habits over 90 \
            days. Using it means agreeing to these terms.
            """
        ),
        LegalSection(
            heading: "Not medical advice",
            body: """
            Fix Me is not a medical device and does not provide medical advice, diagnosis or \
            treatment. Daily scores are motivational metrics invented by the app, not health \
            measurements.

            Recovery timelines shown for quitting are general figures published by public \
            health bodies. They describe typical patterns, not a prediction about you.

            This matters most for alcohol: if you drink heavily or daily, stopping suddenly \
            can be medically dangerous. Talk to a doctor. Never rely on this app in a medical \
            emergency.
            """
        ),
        LegalSection(
            heading: "Alarms are not guaranteed",
            body: """
            Alarms are delivered by iOS notifications, and by in-app audio when Loud alarm is \
            enabled. iOS can delay or withhold notifications, and can shut the app down. Do \
            not rely on Fix Me alone for anything you cannot afford to miss — keep a Clock \
            alarm as backup.
            """
        ),
        LegalSection(
            heading: "Verification is evidence, not proof",
            body: """
            Photo verification is an on-device estimate. It can be wrong in both directions. \
            It records that you submitted a photo and what the analysis made of it — it does \
            not prove you performed a habit, and should not be treated as proof by you or \
            anyone else.
            """
        ),
        LegalSection(
            heading: "Subscriptions",
            body: """
            Premium is an auto-renewing subscription billed through your Apple Account. Any \
            free trial converts to a paid subscription unless cancelled at least 24 hours \
            before it ends. It renews automatically unless cancelled at least 24 hours before \
            the current period ends, and your account is charged for renewal within 24 hours \
            of the period ending.

            Manage or cancel in Settings › Apple Account › Subscriptions. Refunds are handled \
            by Apple under their policies.
            """
        ),
        LegalSection(
            heading: "Your content",
            body: """
            Your habits, photos and journals are yours. They stay on your device; we claim no \
            rights over them. You are responsible for what you record and for anything you \
            choose to share with friends or export.
            """
        ),
        LegalSection(
            heading: "Sharing with others",
            body: """
            When you send progress to a friend, it leaves your device and is out of our \
            control and yours. Only share what you're comfortable with them keeping.
            """
        ),
        LegalSection(
            heading: "No warranty",
            body: """
            Fix Me is provided as-is, without warranties of any kind. We do not guarantee it \
            will be uninterrupted, error-free, or that data will never be lost. Keep your own \
            backups of anything important — Settings › Export my data produces a copy.
            """
        ),
        LegalSection(
            heading: "Changes",
            body: """
            These terms may change as the app changes. Continuing to use Fix Me after an \
            update means accepting the revised terms.
            """
        ),
    ]
}

struct LegalSection: Identifiable {
    let heading: String
    let body: String
    var id: String { heading }
}
