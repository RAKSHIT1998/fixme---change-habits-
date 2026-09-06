# Fix Me

A 90-day habit transformation app for iOS 17+. SwiftUI, SwiftData, HealthKit, StoreKit 2.

## Run it

```bash
brew install xcodegen        # once
xcodegen generate
open FixMe.xcodeproj
```

Pick any iPhone simulator and hit **Run**. No Apple Developer account needed for the
Simulator, and the app is fully usable with no backend or API keys — AI verification runs
on-device through `VisionAIProvider`, and StoreKit purchases run against
`Products.storekit`.

> Set your Development Team in **`Signing.xcconfig`**, not in Xcode's Signing &
> Capabilities tab. Anything Xcode writes into the project file is lost the next time
> `xcodegen generate` runs; the xcconfig survives.

## Signing

One script configures identity and capabilities, then regenerates the project:

```bash
# Simulator only (default — no team required)
./Scripts/configure-signing.sh --profile full --bundle-id com.you.fixme

# Real device, PAID Apple Developer Program account
./Scripts/configure-signing.sh --profile full --bundle-id com.you.fixme --team ABCDE12345

# Real device, FREE Apple ID ("Personal Team")
./Scripts/configure-signing.sh --profile personal --bundle-id com.you.fixme --team ABCDE12345
```

| Profile | HealthKit | App Groups | Works with a free Apple ID |
|---|---|---|---|
| `full` | ✅ | ✅ | ❌ — needs a paid team |
| `personal` | ❌ | ❌ | ✅ |

On the `personal` profile the app detects both are missing and degrades: step and workout
habits fall back to manual completion, and the widget shows placeholder data. Nothing
crashes and no screen becomes unreachable — that path is deliberate, not incidental.

### Deploying to a device (verified working)

Your team `48TGY734WW` is a paid membership, so the `full` profile signs cleanly —
HealthKit and App Groups included. This exact sequence is confirmed working on
Rakshit's iPhone (iOS 27) from Xcode 16.2:

```bash
./Scripts/configure-signing.sh --profile full --bundle-id com.rakshitbargotra.fixme --team 48TGY734WW

xcodebuild -project FixMe.xcodeproj -scheme FixMe \
  -destination 'platform=iOS,id=<device-udid>' -allowProvisioningUpdates build

APP="$HOME/Library/Developer/Xcode/DerivedData/FixMe-*/Build/Products/Debug-iphoneos/Fix Me.app"
xcrun devicectl device install app --device <device-udid> "$APP"
xcrun devicectl device process launch --device <device-udid> com.rakshitbargotra.fixme
```

`xcrun xctrace list devices` prints the UDID. Don't run `devicectl install` while a build
is in flight — installing a half-written bundle fails with a confusing "Info.plist has no
CFBundleIdentifier" error.

## Troubleshooting

**"The app identifier `com.fixme.app` cannot be registered to your development team…"**
That bundle id belongs to someone else. Pick your own:
`./Scripts/configure-signing.sh --profile full --bundle-id com.yourname.fixme`

**"Provisioning profile doesn't support the App Groups and HealthKit capability"**
**"…doesn't include the com.apple.developer.healthkit … entitlements"**
You're signing with a free Personal Team, which Apple does not allow to use either
capability. Either join the paid Developer Program, or build without them:
`./Scripts/configure-signing.sh --profile personal --bundle-id com.yourname.fixme --team YOURTEAMID`

**Signing errors even though you only want the Simulator**
Clear `DEVELOPMENT_TEAM` in `Signing.xcconfig`. With no team, Xcode stops trying to
register the App ID and the errors go away.

## Using the app

The full version of this lives in-app: **Profile → How Fix Me works**. Short version:

1. **Set up** — pick habits, optionally pick something to quit, enter your name, start your 90 days.
2. **Each day** — open Today and tap habits to complete them. Simple habits complete on tap,
   water-style ones open a quick logger, step habits fill in from Apple Health by themselves,
   and `PROVE IT` habits open the camera.
3. **Quitting** — quit habits **count as kept automatically**; you never tick them off. Tap one
   for clean time, money saved and the recovery timeline. Hit *I'm having a craving* for a
   5-minute urge-surfing timer. If you slip, log it — only the current run resets.
4. **Missed a day** — you get a recovery card, not a scolding. A streak freeze (one a month
   free, three on Premium) restores the run you'd built.
5. **Alarms** — Profile → Alarms. Link a habit and the notification gets a Done button you can
   press from the lock screen.
6. **At night** — *Finish your day* on Today: review, journal, add a photo, get your score,
   then share it, post it to your wall, or send it to a friend.
7. **Friends** — Social → Friends. Pair phone-to-phone (Nearby when you're together, an invite
   link at any distance). No account, no server. Nobody can push to you, so check in now and then.
8. **Your data** — stays on device. Export it as JSON or delete all photos from Settings.

## Demo mode

Launch with `-FixMeSeedDemo` to skip onboarding and land on a populated Day 17 journey
(build habits with history, a quit habit mid-run, an alarm). Debug builds only — it wipes
and rewrites the store.

In Xcode: Product > Scheme > Edit Scheme > Run > Arguments > add `-FixMeSeedDemo`.

## Quitting things

Habits come in two kinds. A **build** habit is a daily checkbox. A **quit** habit inverts
it: progress is continuous clean time, it counts as kept unless a relapse is logged, and
it gets its own tracker with money saved, units avoided, cravings resisted and a recovery
timeline.

Three rules this feature is built around:

1. **A relapse resets the current run and nothing else.** Total clean time, longest run and
   attempt count all survive, and the relapse screen leads with what you keep. People who
   quit successfully almost always relapse first; an app that erases their progress is one
   they delete.
2. **Quit habits are never paywalled.** They're exempt from the free-tier habit limit
   entirely — pausing a sobriety counter over billing would be indefensible.
3. **Cravings are the real feature.** The urge-surfing timer turns "I didn't do it" into
   logged, visible progress, which is otherwise invisible work.

Alcohol carries a safety note at setup, because withdrawal from heavy or daily drinking
can be medically dangerous. Recovery timelines are labelled as general published figures,
not personal medical predictions.

## Alarms

Alarm-style reminders with repeat days, snooze, and Done/Snooze actions on the lock
screen — a linked habit can be marked complete without opening the app.

**Platform limit, stated in the UI too:** iOS does not let any third-party app ring
through Silent mode or Do Not Disturb without Apple's Critical Alerts entitlement (a
separate approval). These fire as Time Sensitive notifications, which break through most
Focus modes. For anything genuinely unmissable, the built-in Clock app is still the
answer, and the app says so rather than letting someone find out at 6am.

## Friends — peer-to-peer, no server

Friends are paired **device-to-device**. There is no account, no database and no backend
anywhere in this feature.

**Pairing**
- *Nearby* — MultipeerConnectivity forms an encrypted link directly between two phones over
  Wi-Fi and Bluetooth. Works with no internet at all.
- *Invite link* — a signed `fixme://add-friend?d=…` link sent through iMessage, WhatsApp,
  email, anything. Works at any distance; the messaging app is only a transport.

Your name is asked for at the end of onboarding and is what friends see; change it in
Settings and the peer identity follows. Installs made before that existed adopt their
existing profile name on next launch.

**Trust.** With no server to vouch for anyone, the signature *is* the security model. Each
device holds a Curve25519 keypair whose private half never leaves the Keychain
(`ThisDeviceOnly`, so it isn't even in a backup). Every update is signed over its sender
id, kind, body and timestamp; an update is stored only if it verifies against the public
key captured at pairing. Forged, edited, re-attributed and stranger-sent payloads are all
rejected — there are tests for each.

**What it deliberately cannot do**, because these genuinely require a server:

| | Why |
|---|---|
| Push "your friend updated" to a sleeping phone | Push needs APNs |
| Tell you which contacts already use the app | A directory is a server |
| Deliver while both people are away | Nearby needs proximity; links need sending |

The contact picker runs out of process, so the app needs **no Contacts permission** and
never sees the address book — it only pre-fills an invite message.

## Progress Reel

**Journey › the film icon** builds a vertical video out of the user's own daily photos and
real numbers — hook frame, photo days in order, stats cut in on a rhythm, and a closing
card with their referral code — then hands it to Save to Photos or the share sheet, ready
to post to TikTok, Reels or a story.

It is the app's one outbound growth loop that can actually travel. A static share card gets
a like; a transformation video gets reposted, and the daily photos this app has been
collecting all along were until now write-only.

Everything is generated on device. Scenes are rasterized from SwiftUI with `ImageRenderer`,
then `ReelVideoWriter` encodes them to H.264 with a slow push-in and crossfades. No upload,
no server, no account — the same constraint every other feature here works under.

Three rules it's built around:

1. **Never paywalled.** Gating the feature whose entire job is to bring new people in would
   be taxing the cheapest acquisition channel the app has. Same reasoning as the share-card
   watermark, which every reel also carries.
2. **It works with no photos.** Most people won't have taken daily photos, and a loop that
   only fires for the diligent minority isn't a loop — a stats-only reel is still a reel.
3. **Critical content stays out of the platform's chrome.** TikTok and Reels paint captions
   and buttons over the bottom fifth of the frame. The invite code sits above that line, or
   it ships covered up.

Length is capped in the storyboard (photos are sampled, never all 90) because the invite
lives on the last frame, and nobody reaches the last frame of a two-minute video.

## Social

The Social tab is a working **progress wall**: posts are created from the day recap or the
compose button, carry real stats from that day (day number, completion, streak, habits
kept, optional photo), and support reactions, share and delete. The All / Milestones /
Photos filters each query real data.

What it deliberately does **not** do is pretend to be a community. There is no account and
no server, so no other person can appear in the feed — the screen says exactly that
instead of showing a Following tab that can never populate. `SocialService` is the seam: a
networked implementation (CloudKit's public database is the obvious fit — Apple-hosted, no
server to run) drops in without touching a call site, and the UI's copy switches
automatically via `supportsOtherPeople`.

## Layout

```
FixMe/
  App/            Entry point, DI container, tab shell
  Core/
    DesignSystem/ Tokens + reusable components
    Models/       SwiftData models, catalogs
    Services/     AI, HealthKit, Notifications, Analytics, Storage,
                  Gamification, Subscriptions
    Utilities/    Haptics, image store, preview data
  Features/       Onboarding, Today, Habits, Verification, Journey,
                  Explore, Social, Profile, Sharing, Recap, Paywall, Growth
  Shared/         Code shared with the widget extension
FixMeWidgets/     WidgetKit extension
FixMeTests/       Unit tests
```

Business model, packaging and funnel instrumentation: [MONETIZATION.md](MONETIZATION.md).

## Tests

```bash
xcodebuild -project FixMe.xcodeproj -scheme FixMe \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
