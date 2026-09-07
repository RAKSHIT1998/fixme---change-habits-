# App Store submission — Fix Me

Everything App Store Connect asks for, with the answer already worked out. Answers marked
**⚠️** need a decision or an action from you; the rest can be copied as-is.

---

## 1. URLs (required fields)

The pages are generated into `docs/` and served by GitHub Pages from this repo.

| App Store Connect field | Value |
|---|---|
| **Privacy Policy URL** (required) | `https://rakshit1998.github.io/fixme---change-habits-/privacy.html` |
| **Support URL** (required) | `https://rakshit1998.github.io/fixme---change-habits-/support.html` |
| **Marketing URL** (optional) | `https://rakshit1998.github.io/fixme---change-habits-/` |
| *(not an App Store field)* | `…/i.html` — where every invite and shared-progress link lands. Opens the app if installed, shows the App Store if not. |
| **EULA** | Leave blank — Apple's standard EULA applies. Our Terms of Use page is the in-app copy and does not replace it. |

**Turn Pages on once:** repo → Settings → Pages → Source: *Deploy from a branch* →
branch `main`, folder `/docs` → Save. First build takes a minute or two.
Then open all four URLs and confirm they load before you submit — a dead Privacy or
Support URL is an instant rejection.

⚠️ **Set `APP_STORE_ID` once the app is approved.** Until then `i.html` sends people to
Apple's generic App Store page instead of your listing, which wastes every invite a
non-user taps. Take the Apple ID from App Store Connect → App Information, put it in
`Scripts/generate-legal-html.py`, re-run the generator and push:

```bash
python3 Scripts/generate-legal-html.py     # after setting APP_STORE_ID
```

⚠️ Using a custom domain instead? Run
`python3 Scripts/generate-legal-html.py --domain yourdomain.com`, push, then set the same
domain in repo → Settings → Pages, and swap the URLs above.

---

## 2. App Privacy ("nutrition label")

Answer the questionnaire in App Store Connect → your app → App Privacy.

**Do you or your third-party partners collect data from this app? → No.**

That single answer is the whole section, and it is accurate: there is no account system, no
backend, no analytics SDK, no advertising SDK, and no use of the Advertising Identifier.
Health data, photos and journals are read and stored on-device only. Friend updates travel
device-to-device and are never received by us.

Supporting facts if review asks:

- Purchases go through StoreKit; we see an entitlement flag, never payment details.
- PROVE IT photos are analysed on-device with Apple's Vision framework (`VisionAIProvider`)
  and are never uploaded.
- HealthKit reads are on-device and never transmitted, never used for advertising, and
  never shared — required by Apple's HealthKit review guidelines, and stated in the
  Privacy Policy.
- The Contacts picker runs out of process, so the app has no Contacts permission and never
  reads the address book.

---

## 3. Export compliance

`ITSAppUsesNonExemptEncryption` is already set to `false` in `project.yml`, so no upload
prompt appears. That is the correct answer here:

- Curve25519 signing (CryptoKit) is used for **authentication / digital signatures**, which
  is exempt.
- MultipeerConnectivity's encrypted transport is Apple's own OS-provided encryption, which
  is also exempt.
- No proprietary or non-standard cryptography ships in the app.

If the French declaration screen appears, the app qualifies for the same exemption.

---

## 4. Age rating

Answer the questionnaire like this:

| Question | Answer | Why |
|---|---|---|
| Alcohol, Tobacco, or Drug Use or References | **Infrequent/Mild** | Quit-tracking covers smoking, vaping, alcohol; it is cessation content, not promotion. |
| Medical/Treatment Information | **Infrequent/Mild** | Recovery timelines cite public-health figures; the app labels them as general, not personal medical advice. |
| Everything else (violence, sexual content, gambling, horror, contests) | **None** | |
| Unrestricted web access | **No** | |
| User-generated content shared publicly | **No** | The Social wall is local-only; no other person can ever appear in it. |

That lands in the low-teen tier. ⚠️ If you would rather match the Privacy Policy's "not
directed at children under 13" line exactly, raise the rating a tier — Apple allows a
higher self-selected rating, never a lower one.

---

## 5. In-app purchases — set these up before submitting

Create these in App Store Connect → Monetization, with **exactly** these product IDs
(they come from `Products.storekit` and are hard-coded expectations of the app):

| Product ID | Type | Price in the local config |
|---|---|---|
| `com.fixme.app.premium.monthly` | Auto-renewable, group "Fix Me Premium" | $9.99 / month |
| `com.fixme.app.premium.yearly` | Auto-renewable, same group, **7-day free trial** | $39.99 / year |
| `com.fixme.app.premium.lifetime` | Non-consumable | $79.99 |

⚠️ Note the mismatch: product IDs start `com.fixme.app.` while the bundle id is
`com.rakshitbargotra.fixme`. Apple allows that, but the IDs must be created character-for-character
as above or purchases fail in review. Rename them in both places if you want them to match.

Each IAP needs its own name, description, review screenshot and a submitted-for-review
state. Attach all three to the app version so they review together.

**Paywall compliance — already satisfied** (`FixMe/Features/Paywall/PaywallView.swift`):
price and period shown per plan, renewal terms in the footer text, plus working
**Restore**, **Terms** and **Privacy** buttons. Don't remove any of them.

---

## 6. App Review notes

Paste into "Notes" on the version page:

> Fix Me is a 90-day habit tracker. **No account or login is required** — launch the app and
> onboarding starts immediately, so no demo credentials are needed.
>
> There is no backend of any kind. All data is stored on-device with SwiftData.
>
> Permissions and where they are used:
> • **Health** — Profile › Settings, or any step/workout habit. Read-only, on-device, used
>   solely to auto-complete matching habits. Declining is fully supported: those habits fall
>   back to manual completion.
> • **Camera / Photos** — the "PROVE IT" habit verification flow on the Today tab. The photo
>   is analysed on-device with Apple's Vision framework and never leaves the device.
> • **Notifications** — habit reminders and alarms (Profile › Alarms).
> • **Local Network / Bluetooth** — Social › Friends. Friends are paired directly between two
>   iPhones over MultipeerConnectivity, or via a signed `fixme://add-friend` invite link.
>   **This requires two physical devices**; it cannot be exercised on one device or in the
>   Simulator. The invite-link path can be tested by opening a link on a second device.
>
> The Social tab is a private, on-device progress wall. No other user's content can ever
> appear there, and the UI states this explicitly rather than implying a community.
>
> Subscriptions: Premium is auto-renewing (monthly/yearly) plus a lifetime non-consumable.
> The paywall shows price, period and renewal terms, and has Restore, Terms and Privacy links.
> Quit-tracking (sobriety/cessation) features are deliberately never paywalled.
>
> The app is not a medical device and says so in-app; recovery timelines are labelled as
> general published figures, and the alcohol flow carries a "see a doctor" safety note.

---

## 7. Store metadata

**Name (30):** `Fix Me: 90-Day Habit Tracker`

**Subtitle (30):** `Build habits. Quit the rest.`

**Promotional text (170):**
> 90 days. Real habits, real proof. Track what you're building and what you're quitting —
> with everything stored on your iPhone, no account, no server, no tracking.

**Keywords (100, comma-separated, no spaces):**
`habit,tracker,streak,90,day,quit,smoking,sober,alcohol,routine,discipline,goal,daily,challenge,morning`

**Description:**
> **90 days. Better habits. Better you.**
>
> Fix Me is a 90-day habit tracker built on one idea: showing up is the whole game. Pick the
> habits you're building, name the things you're quitting, and run the full 90 days.
>
> **BUILD**
> Pick your habits and tick them off each day. Water-style habits get a quick logger. Step
> and workout habits fill themselves in from Apple Health. Streaks, XP and badges track the
> run you're putting together.
>
> **PROVE IT**
> Some habits ask for a photo. It's analysed right on your iPhone with Apple's Vision
> framework — the image never leaves your device and no server ever sees it.
>
> **QUIT**
> Quitting gets its own tracker: clean time, money saved, units avoided, cravings resisted
> and a recovery timeline. Feel an urge? Start the 5-minute urge-surfing timer and log the
> win. Slip up? Only the current run resets — total clean time and your longest run survive,
> because relapse is part of quitting, not the end of it. Quit tracking is never locked
> behind a subscription.
>
> **FINISH THE DAY**
> An evening recap: review what you kept, journal it, add a photo, get your score, and post
> it to your own progress wall.
>
> **ALARMS THAT DO SOMETHING**
> Reminders with repeat days and snooze, and a Done button right on the lock screen that
> marks the habit complete.
>
> **FRIENDS, WITHOUT AN ACCOUNT**
> Pair with a friend phone-to-phone over Bluetooth or Wi-Fi, or send a signed invite link.
> There's no account, no directory and no server in between — updates are signed by your
> device and travel straight to theirs.
>
> **YOUR DATA STAYS YOURS**
> No sign-up. No server. No analytics or advertising SDKs. Habits, photos and journals live
> on your iPhone. Export everything as JSON, or delete it all, any time.
>
> Premium unlocks unlimited habits, unlimited verification, streak repair and every share
> template. Quit tracking stays free for everyone.
>
> Fix Me is not a medical device and does not give medical advice. If you drink heavily or
> daily, stopping suddenly can be dangerous — talk to a doctor first.

**What's New (1.0.0):** `First release. 90 days starts now.`

⚠️ Auto-renewing subscription disclosure — Apple requires this in the description or the
App Store's subscription metadata. Append it to the description if you don't put it in the
IAP fields:
> Premium is an auto-renewing subscription. Payment is charged to your Apple Account at
> confirmation of purchase. It renews automatically unless cancelled at least 24 hours
> before the end of the current period, and your account is charged within 24 hours of the
> period ending. Manage or cancel in Settings › Apple Account › Subscriptions. Any unused
> portion of a free trial is forfeited when a subscription is purchased.
> Terms: https://rakshit1998.github.io/fixme---change-habits-/terms.html
> Privacy: https://rakshit1998.github.io/fixme---change-habits-/privacy.html

---

## 8. Screenshots ⚠️

Required: **6.9" iPhone** (1320 × 2868 or 1290 × 2796), up to 10 shots. iPad is not needed —
the app is `TARGETED_DEVICE_FAMILY = 1` (iPhone only). No iPad build, no iPad screenshots.

Fastest way to capture a good set:

```bash
# Debug builds only — seeds a populated Day 17 journey, skipping onboarding
# Xcode: Product > Scheme > Edit Scheme > Run > Arguments > add -FixMeSeedDemo
```

Then on an iPhone 16 Pro Max simulator, ⌘S in the Simulator saves a correctly-sized PNG.
Suggested order: Today (mid-journey), a quit tracker, PROVE IT camera, the day recap /
score, Journey stats, the paywall.

Do **not** show a fake community feed or any content implying other users — the app has
none, and a screenshot that implies otherwise is a rejection risk.

---

## 9. Pre-flight code checks

- [ ] `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` bumped for each upload.
- [ ] Archive with the **Release** configuration. The `Products.storekit` file is attached to
      the *Run* action only, so a Release archive already talks to the real App Store — but
      confirm it after any scheme edit.
- [ ] `VisionAIProvider` is the injected provider in `AppContainer.swift` (it is today).
      `MockAIProvider` must never ship. *(The root README still says verification runs on the
      mock — that line is stale.)*
- [ ] Build for a real device with `--profile full` so HealthKit and App Groups entitlements
      are present: `./Scripts/configure-signing.sh --profile full --bundle-id com.rakshitbargotra.fixme --team 48TGY734WW`
- [ ] App icon present at every size (`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`) with no
      alpha channel.
- [ ] Regenerate the site after any edit to `LegalDocuments.swift` so the hosted text and the
      in-app text match — review compares them: `python3 Scripts/generate-legal-html.py`
- [ ] `xcodebuild ... test` passes.
- [ ] `APP_STORE_ID` is set in `Scripts/generate-legal-html.py` and `docs/i.html`
      regenerated — see §1. Tap an invite link on a device without the app to confirm it
      lands on your listing.

---

## 10. Two things review may ask about

**"You both get a free week" — where does that come from?** Pairing with a friend grants
each device a week of Premium locally (`ReferralCredit`), capped at 28 days lifetime and
once per friend. It is not a purchase, involves no server, and unlocks the same features a
subscription does. Nothing is collected about either person.

**Challenges and the "$50 stake".** The app records a pledge and never collects, holds,
charges or refunds money. There is no payment flow, no IAP involved, and no third party
receives funds — `StakeChallenge` stores an amount the user typed and the name of whoever
they told. Settling up happens entirely outside the app. This is stated on the setup screen
above the confirmation toggle and again on the challenge screen, so a reviewer will see it
without going looking.

**The rating prompt.** `ReviewPrompt` uses the standard `requestReview` action and only
fires after a completed day scoring 80+, or on a milestone day, no earlier than day 7 and
at most once per version. It never appears during onboarding, after a missed day, or
anywhere near the paywall.

---

## 11. Things Apple rejects apps like this for

- **Dead Support URL.** The single most common one. Check it in a private window.
- **Hosted policy that doesn't match the in-app policy.** Handled by the generator — keep
  using it instead of hand-editing `docs/*.html`.
- **HealthKit data used for anything but the stated feature**, or a missing statement that
  health data isn't used for advertising. Both are covered in the Privacy Policy.
- **Subscription paywall missing price, renewal terms, Restore, Terms or Privacy.** Present.
- **Medical claims.** The app frames scores as motivational and timelines as general figures.
  Don't add anything that reads as diagnosis or treatment.
- **Alcohol/tobacco content without an age rating to match.** See §4.
