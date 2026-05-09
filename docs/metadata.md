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
| Version (MARKETING_VERSION) | 1.0 |
| Build (CURRENT_PROJECT_VERSION) | 1 |

## Version localization (en-US)

### Promotional text (170 chars, editable without new build)

Remember everyone who matters. A daily reconnect list and reminders — all on your iPhone. Nothing leaves your device unless you say so.

### Description (≤4,000 chars)

RelationOS is a personal CRM that lives entirely on your phone.

Most relationship apps want your contacts uploaded to their servers. RelationOS doesn't. Your people, your notes, your reminders — all of it stays on your iPhone. No account. No data leaves your device.

WHAT IT DOES

• Remember everyone — Add contacts, notes, and tags as you meet people. The little things they share with you survive on your phone, ready next time it matters.

• Daily reconnect list — Five people every morning who are slipping away. See who you're losing touch with before the relationship goes cold.

• Cooling relationships highlighted — Contacts you haven't heard from in a while bubble up first, so you reach out before it's too late.

• Reminders — "Follow up in 2 weeks." Local notifications fire on your phone — no server, no calendar dependency.

• Notes that survive — Capture the small things people share with you. Their kid's name. The book they recommended. The conflict they're working through.

• iOS-native — Home Screen and Lock Screen widgets surface your daily reconnect list at a glance.

PRIVACY FIRST

• 100% on-device by default
• No account required
• No tracking, no analytics that identify you
• Your data stays on your iPhone — no cloud back-end. Cross-device support is on the v1.1 roadmap.

PERFECT FOR

• Founders, investors, and operators who keep big networks alive
• Job seekers maintaining warm leads
• Anyone who wants to be the kind of person who follows up

PRICING

• Free: track up to 100 contacts with notes and reminders
• Pro: unlimited contacts, daily reconnect list (5 people every morning), cooling-relationships highlighting, daily reconnect widget content
  - $11.99 / month
  - $89.99 / year (save 37%)
  - 14-day free trial — no card required

Cancel anytime in iOS Settings.

Privacy policy: https://has-deploy.github.io/relationos/privacy
Support: https://has-deploy.github.io/relationos/support

> Guideline 2.3.1: description must accurately describe what the app does.
> Every feature claimed here must actually work in the build. Do not claim
> "unlimited" / "fully offline" / competitor-better phrasing unless you can
> back it up in the app. If the app has a subscription AND the EULA is
> Apple's standard one (no custom EULA uploaded), include a line like:
> "Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

### Keywords (100 chars, comma-separated, no spaces)

personal crm,relationship,contacts,reminders,follow up,network,private,offline,memory,reconnect

### Support URL

https://has-deploy.github.io/relationos/support

### Marketing URL (optional)

https://has-deploy.github.io/relationos/

### What's New (release notes, per version)

Initial release. RelationOS keeps your relationships private — on your phone, not in the cloud.

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
| app.relationos.pro.monthly | RelationOS Pro Monthly | $11.99 / month (Tier 12) | Auto-renewable subscription. 2-week free trial. Group: RelationOS Pro. |
| app.relationos.pro.annual | RelationOS Pro Annual | $89.99 / year (Tier 90) | Auto-renewable subscription. 2-week free trial. Group: RelationOS Pro. |

## Screenshots

Place PNGs in `~/Developer/relationos/screenshots/` in the following
structure:

```
screenshots/
  iphone-6.9/  3-10 PNGs, 1320×2868 or 2868×1320
  ipad-13/     3-10 PNGs, 2064×2752 or 2752×2064
```

Stage 7 uploads them via `POST /v1/appScreenshotSets`.
