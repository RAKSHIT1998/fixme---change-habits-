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

The app record exists: **Apple ID `6809448798`**, name **Fix Me: 90-Day Habits**, bundle id
`com.rakshitbargotra.fixme`. (The plain name "Fix Me" was already taken — App Store names
are globally unique.) `APP_STORE_ID` is set in the generator, so invite links land on the
real listing.

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

**These now exist** — created via the App Store Connect API (`Scripts/appstore-connect.py`)
against app `6809448798`:

| Product ID | Type | Localized | Price |
|---|---|---|---|
| `com.fixme.app.premium.monthly` | Auto-renewable, group "Fix Me Premium" (22366183) | ✅ | ⚠️ **not set** — $9.99 |
| `com.fixme.app.premium.yearly` | Auto-renewable, same group | ✅ | ⚠️ **not set** — $39.99, plus the 7-day free trial |
| `com.fixme.app.premium.lifetime` | Non-consumable | ✅ | ✅ $79.99 |

⚠️ **Set the two subscription prices and the free trial in the web UI.** The API refuses
them: `POST /v1/subscriptionPrices` returns `409 ENTITY_ERROR.RELATIONSHIP.INVALID`
pointing at `subscriptionPricePoint/id`, using a price point read moments earlier from that
same subscription's own `/pricePoints` endpoint. The account is not the problem — the
non-consumable's price went through the equivalent `inAppPurchasePriceSchedules` endpoint
on the first try. Payload shape, territory, and stale-token theories were all ruled out. It
takes about two minutes by hand:

> Monetization → Subscriptions → Fix Me Premium → each subscription → **Subscription Prices**
> → Add Price → United States → 9.99 / 39.99. Then on the yearly one, **Introductory
> Offers** → Free trial, 1 week, all territories.

Note the product IDs start `com.fixme.app.` while the bundle id is
`com.rakshitbargotra.fixme`. Apple allows it, and **they are now permanent** — a product ID
can never be renamed or reused once created.

Names and descriptions are done. Each product still needs a **review screenshot**, which
can only be uploaded through the web UI, and all three must be attached to the app version
so they review together.

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

**Name (30):** `Fix Me: 90-Day Habits` — already registered under this name.

**Subtitle (30):** `Build habits. Quit the rest.`

**Promotional text (170):**
> 90 days. Real habits, real proof. Track what you're building and what you're quitting —
> with everything stored on your iPhone, no account, no server, no tracking.

**Keywords (100, comma-separated, no spaces):**
`habit,tracker,streak,90,day,quit,smoking,sober,alcohol,routine,discipline,goal,challenge,morning`

(100 characters is a hard limit — the earlier list was 102 and would have been rejected.)

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

There's a harness for this — it drives the real app on a simulator and captures at
native resolution, so the sizes are always exactly right:

```bash
xcodebuild -project FixMe.xcodeproj -scheme FixMeScreenshots \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

PNGs land in `/private/tmp/fixme-screenshots` (override with `FIXME_SCREENSHOT_DIR`). It
launches with `-FixMeSeedDemo`, so every shot shows a populated day-17 journey rather than
an empty first launch, and it captures Today, Journey, Explore, Social and Profile.

**Run it on an iPhone 16 Pro Max.** That device is natively 1320x2868, which is the 6.9"
size Apple wants; the test asserts the dimensions and fails on any other simulator. It also
fails if a capture comes back blank — an earlier version rendered the screens headlessly
with `ImageRenderer` and produced six identical grey placeholders that passed a
size-only check, which is exactly the failure worth catching.

Add anything the automated set doesn't cover (the paywall, a quit tracker, the reel) by
hand, or extend `FixMeUITests/AppStoreScreenshots.swift`.

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
- [x] `APP_STORE_ID` set to 6809448798 and `docs/i.html` regenerated. Still worth tapping
      an invite link on a device without the app once the listing is live.
- [ ] **Build somewhere with Xcode 26.** App Store Connect rejects anything built against
      an SDK older than iOS 26 — validation fails with a 409 before review sees it. The
      project's own Mac cannot do this at all (see below), so use the CI workflow.

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

## 11. Where builds come from

**The development Mac cannot produce an App Store build, and never will.** It is a 2019
Intel MacBook Air (MacBookAir8,2), which macOS Sequoia dropped support for — so it is
stuck on Sonoma 14. Xcode 26, which carries the required iOS 26 SDK, needs both a newer
macOS and Apple Silicon. There is no upgrade path on that hardware, and only ~15 GB free
against Xcode's ~40 GB anyway. Everything else in this repo works there; distribution
doesn't.

Three ways to build elsewhere, in the order worth trying. Note that being on an Intel Mac
does not rule out any of them: all three build on someone else's Apple Silicon hardware,
and this machine only ever configures them.

### Option Z — straight from Xcode, on a Mac that can run Xcode 26

Nothing in this project needs changing for this. It archives and exports a correctly
signed App Store IPA today — that has been verified end to end here; the upload was
rejected only for the SDK stamp, which is a property of the compiler, not the code.

On any Mac running Xcode 26 (Apple Silicon):

```bash
git clone https://github.com/RAKSHIT1998/fixme---change-habits-.git
cd fixme---change-habits-
brew install xcodegen && xcodegen generate    # the .xcodeproj is generated, not committed
open FixMe.xcodeproj
```

Then: select **Any iOS Device** as the destination → **Product → Archive** → **Distribute
App → App Store Connect → Upload**. Signing is automatic and the team is already set to
48TGY734WW in `Signing.xcconfig`, so it should need no further configuration.

Bump `CURRENT_PROJECT_VERSION` in `project.yml` before each upload — build numbers cannot
be reused — and re-run `xcodegen generate`.

### Option A — Xcode Cloud (recommended)

Apple's own CI. It is included with the Developer Program (25 compute hours/month free),
runs current Xcode by definition, and **manages signing itself**, so none of the secrets
below are needed.

1. App Store Connect → your app → **Xcode Cloud** tab → **Get Started**
2. Grant it access to the GitHub repo when asked
3. Create a workflow: **Archive** action, **iOS**, branch `main`
4. Under Post-Actions add **TestFlight (Internal Testing)**
5. Save and run

`ci_scripts/ci_post_clone.sh` is already in the repo and is what makes this work: the
`.xcodeproj` is generated by XcodeGen and not committed, so without that hook Xcode Cloud
clones the repo and finds nothing to build. It installs XcodeGen and runs `xcodegen
generate` before the build starts.

### Option B — Codemagic (`codemagic.yaml`)

Needs neither this Mac nor GitHub billing. Sign up at codemagic.io on the free tier,
connect the repo, add the App Store Connect key (`RD4DGF9Y57`, issuer
`6f3b9fe1-e2ff-42e4-9d77-04e29bcc428a`, plus the `.p8`) as a team integration named
`fixme-asc`, and run `ios-release`. That is the entire setup — no variables to paste.

Signing is done by `xcodebuild -allowProvisioningUpdates` with that same key, the way the
IDE does it when you hit Archive: Xcode generates the keypair on the runner and registers
the certificate and profile itself. The earlier config used codemagic-cli-tools'
`fetch-signing-files`, which cost three failed builds — it needs a certificate private key
supplied by hand, because Apple's API creates certificates but never returns their private
half, and a PEM pasted into a variable field loses its newlines. Nothing to transport now,
so none of that can recur.

### Option C — GitHub Actions

Blocked at the time of writing: the account is billing-locked, so jobs refuse to start
("The job was not started because your account is locked due to a billing issue"), which
applies even though Actions is free on public repositories. Once that is cleared:
**Actions → "Upload to App Store Connect" → Run workflow**
(`.github/workflows/release.yml`). It selects the newest Xcode and fails immediately if it
is older than 26, imports signing into a throwaway keychain, archives, exports, validates,
then uploads. Build numbers come from the run number, because a build number can never be
reused.

**One-time setup — five repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Where it comes from |
|---|---|
| `ASC_KEY_ID` | App Store Connect → Users and Access → Integrations (e.g. `RD4DGF9Y57`) |
| `ASC_ISSUER_ID` | Same page, the UUID above the key list |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
| `DIST_CERT_P12_BASE64` | Keychain Access → "Apple Distribution: Rakshit Bargotra" → export as .p12 **with its private key**, then `base64 -i dist.p12 \| pbcopy` |
| `DIST_CERT_PASSWORD` | The password you set on that .p12 export |

The alternative is any Apple Silicon Mac running Xcode 26 — then `xcodebuild archive` and
Transporter work directly, and this workflow is unnecessary.

---

## 12. Things Apple rejects apps like this for

- **Dead Support URL.** The single most common one. Check it in a private window.
- **Hosted policy that doesn't match the in-app policy.** Handled by the generator — keep
  using it instead of hand-editing `docs/*.html`.
- **HealthKit data used for anything but the stated feature**, or a missing statement that
  health data isn't used for advertising. Both are covered in the Privacy Policy.
- **Subscription paywall missing price, renewal terms, Restore, Terms or Privacy.** Present.
- **Medical claims.** The app frames scores as motivational and timelines as general figures.
  Don't add anything that reads as diagnosis or treatment.
- **Alcohol/tobacco content without an age rating to match.** See §4.
