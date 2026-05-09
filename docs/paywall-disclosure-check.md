# Paywall Disclosure Check — RelationOS

> **If this app has any auto-renewable subscription**, every box below must
> be checked before the build ships. Missing any single one is a HARD
> rejection under **Guideline 3.1.2(a/c)**. The paywall-hard-gate.py script
> reads this file and fails if any box is unchecked.

App has a subscription? Yes

If the answer above is **no**, stop here — this file does not apply.

---

## In-app checklist (visible on the paywall screen the reviewer will see)

- [x] Subscription **title** displayed (matches ASC reference name)
- [x] Subscription **length** displayed ("monthly" / "yearly" / "week" / etc.)
- [x] **Price** per period displayed (e.g. "$4.99/month")
- [x] Price-per-unit displayed if not obvious on the primary unit
      (e.g. "$59.99/year (~$5/month)")
- [x] Exact sentence present, verbatim:
      **"Payment will be charged to your Apple ID account at
      confirmation of purchase."**
- [x] Exact sentence present, verbatim:
      **"Subscription automatically renews unless canceled at least 24
      hours before the end of the current period."**
- [x] Exact sentence present, verbatim:
      **"Your account will be charged for renewal within 24 hours prior
      to the end of the current period."**
- [x] Exact sentence present, verbatim:
      **"Subscriptions may be managed and auto-renewal may be turned off
      by going to the user's Account Settings after purchase."**
- [x] Tappable **Privacy Policy** link — opens live URL (not `mailto:`)
- [x] Tappable **Terms of Use (EULA)** link — opens live URL
- [x] **Restore Purchases** button visible
- [x] Cancel / Dismiss button visible (not a dark pattern — reviewer must
      be able to close the paywall without buying)

## ASC metadata checklist

- [ ] Privacy Policy URL populated on App Information tab (200 OK on GET)
- [ ] EULA handled via one of:
      - [ ] Custom EULA uploaded in ASC → App Information → Custom EULA, OR
      - [ ] Terms of Use URL referenced in App Description field
- [ ] Each subscription has its own App Store Review screenshot uploaded
      via `POST /v1/subscriptionAppStoreReviewScreenshots` (IAP-level
      screenshot on version does NOT cover subs)
- [ ] Each subscription has pricing across all available territories
      (run Stage 4C `subscriptionSubmissions` validator)
- [ ] Each subscription state is `READY_TO_SUBMIT` before the version is
      submitted (see Stage 4C "poke reviewNote" pattern)

## Paywall screenshot evidence

Attach the paywall screenshot(s) that prove the disclosures above are
actually visible without scrolling:

- `screenshots/paywall-primary.png`
- `screenshots/paywall-scroll-bottom.png` (if disclosures are below the fold)

The reviewer must see all disclosures on one screen or with obvious
scrolling within the same view. Hiding disclosures behind a "?" button is a
rejection risk.

## Source file(s) implementing the paywall

RelationOS/Features/Paywall/PaywallView.swift, RelationOS/Core/Purchases/PurchaseManager.swift
<!--
  e.g. MacroDinnerPlanner/Features/Paywall/PaywallView.swift:1-320
       Core/Purchases.swift (StoreKit wiring)
-->

## Link reachability check (run before every submission)

```bash
curl -sSfI https://has-deploy.github.io/relationos/privacy >/dev/null && echo "privacy OK"
curl -sSfI https://has-deploy.github.io/relationos/terms   >/dev/null && echo "terms OK"
```

Both should print `OK`. If not, fix hosting before shipping.
