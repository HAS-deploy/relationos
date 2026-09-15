# CHANGE_REPORT — RelationOS 1.1.3

**App:** RelationOS (`com.relationos.app`)
**Ship target:** 1.1.3 (8)
**Base:** `cos/relationos-1.1.3-upgrade`
**Date:** 2026-09-15
**ASC submit:** no (version bump only; do not upload)

## Why this build

Finish the 1.1.3 upgrade already staged on `cos/relationos-1.1.3-upgrade`: lock the 14-day install trial end-to-end, make PostHog a live first-wire (not a dead `start()`), ship approved on-device Foundation Models extraction with a safe fallback, and align privacy answers with the manifest.

## 1. Install trial — 14 days SoT

`IntroTrialClock.length` is `14 * 24 * 60 * 60`. Settings / paywall / PurchaseManager copy already said 14 days; unit tests still asserted 7 after the 2026-05-18 portfolio experiment.

| Surface | Status |
|---|---|
| `IntroTrialClock.length` | 14 days |
| Settings banner + debug reset | 14-day copy |
| Paywall trial banner / microcopy | dynamic days remaining |
| `testFreshInstallGrantsTrialAndProForFourteenDays` | asserts 14 |
| Rewind QA path | day 13 → 1 day left |
| Consume-on-paid | kept; new unit covers it |

No StoreKit introductoryOffer. Trial is still the local install stamp. Paid purchase still consumes the trial so it cannot stack.

## 2. Analytics — first-wire is live

Portfolio pattern (same PostHog SPM + `PostHogKey` / `PostHogHost` as other HAS-deploy apps; key already present, not invented):

- SwiftPM: `https://github.com/PostHog/posthog-ios` → product `PostHog`
- Info.plist + `project.yml`: `PostHogKey` (`phc_zsZ6K…`), `PostHogHost` (`https://us.i.posthog.com`)
- `PortfolioAnalytics.shared.start(appName: "relationos")` in `RelationOSApp.init`
- Privacy-strict SDK config unchanged: `personProfiles=.never`, `captureScreenViews=false`, `captureApplicationLifecycleEvents=false`, `sessionReplay=false`
- Explicit events now emitted so the SDK is not idle after `start()`:
  - `install` (first launch)
  - `app.foregrounded` (launch + scene active)
  - `screen.viewed` — contacts / reconnect / settings / contact_detail / paywall
  - `paywall.viewed` / `paywall.purchase_clicked` / `paywall.purchase_success` / `paywall.purchase_failed` (incl. `product_unavailable`)
  - `paywall.restore_clicked` / `restore.completed`
- `PurchaseManager.syncAnalyticsEntitlement()` maps trial / paid / free → `user_segment`
- Settings toggle writes `portfolio.analytics.opted_out`; `track()` no-ops when opted out

### Privacy alignment (not "Data Not Collected")

`PrivacyInfo.xcprivacy` and `docs/app-privacy-answers.md` now agree:

| Type | Collected | Linked | Tracking |
|---|---|---|---|
| User ID (random per-install) | Yes | No | No |
| Product Interaction | Yes | No | No |
| Crash Data | Yes | No | No |
| Performance Data | Yes | No | No |
| Other Diagnostic Data | Yes | No | No |

Risk profile §5, App Review notes, and `docs/privacy.html` updated to match. Source-level `AnalyticsHardGateTests` guards the wire.

## 3. Foundation Models — local, capability-checked

Approved scope: note → structured memory (brief, remembered facts, follow-ups). Email digest already used the same APIs.

Verified against current Apple docs (`SystemLanguageModel.default.availability`, `LanguageModelSession(instructions:)`, `respond(to:generating:)`, `@Generable` / `@Guide`). No invented APIs. No training. Nothing leaves the device.

| Device state | Behavior |
|---|---|
| iOS 26+ and `.available` | On-device generation |
| `.deviceNotEligible` / `.appleIntelligenceNotEnabled` / `.modelNotReady` | User-facing reason + heuristic sketch |
| Older OS / no framework | Heuristic sketch |
| Generation throws | Heuristic sketch |

UI: Contact detail → "On-device brief" with extract / refresh. Footer states on-device + no training. Email summarizer uses the same availability switch.

## 4. Version

| Target | Marketing | Build |
|---|---|---|
| RelationOS | 1.1.3 | 8 |
| RelationOSWidgets | 1.1.3 | 8 |

Previous ship on this branch was 1.1.2 (7). No ASC upload from this change.

## 5. Tests added / updated

- `IntroTrialClockTests` — length, 14-day remaining, expiry, consume, stamp stability
- `PurchaseManagerTests` — 14-day grant, rewind 13→1, consume-on-paid
- `ContactMemoryExtractorTests` — empty notes, heuristic brief/facts/follow-ups, availability probe
- `AnalyticsHardGateTests` — SPM, plist keys, `start()`, screens, paywall events, opt-out, privacy Yes-collected

Units that need an iOS host (`xcodebuild test -scheme RelationOS`) were not executed in this Linux agent environment.

## Out of scope

- App Store Connect submit / metadata push
- Inventing a new PostHog project key
- Cloud / training / off-device LLM
- SwiftData migration

## Builder Mac verify 2026-09-15

- Worktree: `/Users/tony/Developer/builder-relationos-pr2-20260915` @ PR #2 head
- Fixed stale `PricingConfigTests.testPaywallBenefitsMatchTrimmedV1Scope` (expected 4 bullets incl. separate cooling; SoT is 3 with cooling folded into Daily Reconnect line)
- Re-run: `xcodebuild test -scheme RelationOS -only-testing:RelationOSTests` → see follow-up log
- **No ASC submit**
