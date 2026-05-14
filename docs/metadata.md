# ASC Metadata — RelationOS

> Source of truth for what Stage 7 (`asc_metadata.py`) will push to App
> Store Connect. Keep this file synchronized with what's actually in ASC.
> Discrepancies between this file and ASC are a Stage 4A hard finding.

## App info (App Information tab)

| Field | Value |
|---|---|
| Name | RelationOS |
| Subtitle (30 chars max) | Personal CRM. On your phone. |
| Primary category | Productivity |
| Secondary category | Lifestyle |
| Privacy policy URL | https://has-deploy.github.io/relationos/privacy |
| Privacy choices URL | (usually same as privacy URL) |

## Version info (per build)

| Field | Value |
|---|---|
| Version (MARKETING_VERSION) | 1.1 |
| Build (CURRENT_PROJECT_VERSION) | 4 |

## Version localization (en-US)

### Promotional text (170 chars, editable without new build)

Remember everyone who matters. A daily reconnect list and reminders, on your iPhone. Your contacts and notes stay on-device.

### Description (≤4,000 chars)

RelationOS is a personal CRM that lives on your phone.

Most relationship apps want your contacts uploaded to their servers. RelationOS doesn't. Your people, your notes, and your reminders stay on your iPhone. No account. Contact data never leaves your device.

WHAT IT DOES

• Remember everyone — Add contacts, notes, and tags as you meet people. Import them in seconds from your iPhone Contacts (pick selectively or in bulk) or from a vCard attachment.

• Daily reconnect list — Five people every morning who are slipping away. See who you're losing touch with before the relationship goes cold.

• Cooling relationships highlighted — Contacts you haven't heard from in a while bubble up first, so you reach out before it's too late.

• Quick log — One tap to call, text, or email a contact through Apple's standard composers. RelationOS records what you sent — iOS doesn't share call or text history with third-party apps, so the log is the substitute.

• Reminders — "Follow up in 2 weeks." Local notifications fire on your phone, no server, no calendar dependency.

• Notes that survive — Capture the small things people share. Their kid's name. The book they recommended. The conflict they're working through.

• iOS-native — Home Screen and Lock Screen widgets surface your daily reconnect list at a glance.

PRIVACY

• Contacts, notes, and reminders are stored only on your device.
• No account required.
• Anonymous product analytics (PostHog) help us improve the app; they never include your contact data and are detailed in the privacy policy.
• Cross-device sync is on the roadmap and is off by default.

PERFECT FOR

• Founders, investors, and operators who keep big networks alive
• Job seekers maintaining warm leads
• Anyone who wants to be the kind of person who follows up

PRICING

• Free for the first 14 days from install — full Pro, no card required.
• After day 14: free tier (up to 100 contacts, notes, reminders, quick-log composers, contact import). Pro unlocks unlimited contacts, the Daily Reconnect list, and cooling-relationships highlighting.
  - $11.99 / month
  - $89.99 / year (save 37%)

Subscriptions auto-renew unless canceled at least 24 hours before the period ends. Manage or cancel in iOS Settings → your Apple ID → Subscriptions.

Privacy policy: https://has-deploy.github.io/relationos/privacy
Terms of Use: https://has-deploy.github.io/relationos/terms
Support: https://has-deploy.github.io/relationos/support

> Guideline 2.3.1: description must accurately describe what the app does.
> Every feature claimed here must actually work in the build. Do not claim
> "unlimited" / "fully offline" / competitor-better phrasing unless you can
> back it up in the app. Subscription apps MUST link Terms+Privacy in the
> App Description (3.1.2(c)).

### Keywords (100 chars, comma-separated, no spaces)

personal crm,relationship,contacts,reminders,follow up,network,private,offline,memory,reconnect

### Support URL

https://has-deploy.github.io/relationos/support

### Marketing URL (optional)

https://has-deploy.github.io/relationos/

### What's New (release notes, per version)

Import your iPhone contacts (pick a few or in bulk) or a vCard. Log a call, text, or email per person. Stability and reliability improvements.

## Review information

| Field | Value |
|---|---|
| Contact first name | Tony |
| Contact last name | McMurtrey |
| Contact email | tony@medbillresolve.com |
| Contact phone | +12102106034 |
| Demo required | No |
| Demo username | (none required) |
| Demo password | (none required) |
| Review notes | (see `docs/app-review-notes.md` — paste into ASC Notes field) |

## Age rating

Answers set by `asc_metadata.py` — Apple's API wants literal booleans for
some and strings for others. Defaults:

- Cartoon/fantasy violence: `NONE`
- Realistic violence: `NONE`
- Prolonged graphic / sadistic violence: `NONE`
- Profanity / crude humor: `NONE`
- Sexual content or nudity: `NONE`
- Horror/fear themes: `NONE`
- Alcohol, tobacco, drug use: `NONE`
- Mature/suggestive themes: `NONE`
- Simulated gambling: `NONE`
- Medical/treatment information: `NONE`
- Unrestricted web access: `False`
- Gambling and contests: `False`
- Gambling (simulated): `NONE`
- Contests (user-generated): `False`

Override only when the app actually matches — e.g. AI content apps
typically bump to 17+.

## Content rights

`DOES_NOT_USE_THIRD_PARTY_CONTENT` unless RelationOS bundles copyrighted
third-party material.

## Pricing

| Tier | Territory |
|---|---|
| Free, with auto-renewable subscription IAP at $11.99/mo (Tier 12) or $89.99/yr (Tier 90) | USA |

See Subscriptions playbook in `~/Documents/app-factory-workflow.md` for
setting per-territory prices when subs exist.

## IAP metadata (if any)

| Product ID | Reference name | Price | Subscription? |
|---|---|---|---|
| app.relationos.pro.monthly | RelationOS Pro Monthly | $11.99 / month (Tier 12) | Auto-renewable subscription. No introductory free trial — the 14-day Pro period is an install-time grant in the app, not a StoreKit introductory offer. Group: RelationOS Pro. |
| app.relationos.pro.annual | RelationOS Pro Annual | $89.99 / year (Tier 90) | Auto-renewable subscription. No introductory free trial — the 14-day Pro period is an install-time grant in the app, not a StoreKit introductory offer. Group: RelationOS Pro. |

## Screenshots

Place PNGs in `~/Developer/relationos/screenshots/` in the following
structure:

```
screenshots/
  iphone-6.9/  3-10 PNGs, 1320×2868 or 2868×1320
  ipad-13/     3-10 PNGs, 2064×2752 or 2752×2064
```

Stage 7 uploads them via `POST /v1/appScreenshotSets`.

> **v1.1 screenshot re-shoot required.** v1.0 screenshots show "Start
> 14-day free trial" CTA, "14-day free trial" plan microcopy, and a
> DEBUG-only Settings section that no longer exist in v1.1. Re-capture
> from a Release build before resubmitting.
