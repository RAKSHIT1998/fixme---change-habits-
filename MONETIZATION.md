# Fix Me — Monetization & Retention

How the business model is wired into the app, and what to do before shipping.

## Packaging

| | Free | Premium |
|---|---|---|
| Habits | 3 active | Unlimited |
| AI photo verification | 3 / week | Unlimited |
| Share templates | 3 of 10 | All 10, all formats |
| Streak freezes | 1 / month | 3 / month |
| Streak repair (past days) | — | ✅ |
| Advanced insights, AI coaching | — | ✅ |
| Habits, streaks, 90-day journey, history, sharing | ✅ | ✅ |

The free tier deliberately keeps the whole core loop. A habit app only converts users who
are still opening it in week three, so crippling week one is self-defeating.

**Prices** (`Products.storekit`, mirror these in App Store Connect):

- Yearly **$39.99** with a **7-day free trial** — the plan the paywall pre-selects
- Monthly **$9.99** — exists mainly to make the yearly plan's *SAVE 67%* badge true
- Lifetime **$79.99** — captures subscription-averse buyers; meaningful ARPU bump

## Where the paywall appears

Contextual paywalls out-convert one generic screen, so each entry point has its own copy
(`PaywallTrigger`):

| Trigger | Fires when | Why it converts |
|---|---|---|
| `onboardingComplete` | Right after "START MY 90 DAYS" | Peak commitment — the single best placement |
| `habitLimit` | Adding a 4th habit, or tapping a paused one | User is asking for the exact thing being sold |
| `aiVerificationQuota` | 4th AI verification in a week | They've felt the feature work |
| `streakRepair` | Out of freezes after a missed day | Loss aversion; highest intent of all |
| `premiumTemplate` | Tapping a locked share template | Low-stakes, high-frequency |
| `settings` | Manual browse | Baseline |

Habits set up during onboarding are **never deleted** when they exceed the free limit —
they stay visible and paused (`LockedHabitRow`). Preserving the user's own setup is both
the honest choice and a better daily conversion surface than a banner.

## Retention mechanics

Retention *is* the revenue model: LTV is roughly ARPU × months retained.

- **Streak + loss aversion** — `StreakAtRiskBanner` after 5pm when a live streak has open habits
- **Recovery, not punishment** — `ComebackCard` the morning after a miss; freezes restore a
  broken streak (`StreakFreezeService.recoverableStreak`)
- **Behavioral notifications** — `SmartNotificationEngine`, capped at 3/day, each tied to real
  state (day start, streak at risk, day close, milestone eve). Volume is a one-way door: users
  who feel spammed revoke permission permanently, and a habit app without notifications has no
  way to bring anyone back.
- **Milestones** — anticipation ("Halfway is tomorrow") drives opens better than congratulation
- **Investment** — photos, journals and history accumulate, raising switching cost honestly

## Growth loops

- **Share cards** carry the `FIX ME` watermark for free *and* paying users. Selling watermark
  removal would tax the app's cheapest acquisition channel — never do it.
- **Referrals** (`ReferralView`) — symmetric offer, a free week each. Accountability partners
  genuinely finish challenges more often, so this is a feature, not just a growth hack.

## Funnel instrumentation

`AnalyticsEvent` already emits the events that tell you whether this works. Wire
`ConsoleAnalyticsService` to a real vendor and watch:

`paywall_viewed` → `checkout_started` → `subscription_started`, split by trigger, plus
`feature_gate_hit`, `streak_saved`, `comeback_after_missed_day`, `referral_shared`.

Category benchmarks worth measuring against: **trial start 3–8%** of paywall views,
**trial→paid 25–45%**, **D1 retention 35–50%**, **D30 15–25%**. If trial→paid is low, the
trial is too long or onboarding over-promised. If `paywall_viewed` is high but
`checkout_started` is low, the price anchor is wrong before the copy is.

## Before shipping

1. Create the three products in App Store Connect with the IDs in `SubscriptionProduct`.
2. Add the 7-day intro offer to the yearly plan.
3. Remove `storeKitConfiguration: Products.storekit` from the scheme in `project.yml`
   (it's a local testing stub — real builds must hit the real store).
4. Add real Terms and Privacy URLs to the paywall footer buttons — Apple rejects paywalls
   without them.
5. Server-side receipt validation before trusting entitlements for anything costly.
6. A/B the paywall headline and the trial length (7 vs 3 days) first — biggest levers.
