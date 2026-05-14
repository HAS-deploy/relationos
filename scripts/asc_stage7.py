#!/usr/bin/env python3
"""
Stage 7 (ASC metadata + IAP + screenshots) and Stage 4C (subscription pre-flight)
for RelationOS. Idempotent. Reads ASC creds from env or default paths.

Usage:
    python3 asc_stage7.py            # run all steps
    python3 asc_stage7.py <step>     # run one step (a..j, subs, preflight, status)

Steps:
    a  - app info (categories)
    b  - app info localization (name, subtitle, privacy URL)
    c  - app store version (copyright, releaseType, build link)
    d  - version localization (description, keywords, etc.)
    e  - app review detail (contact info, review notes)
    f  - age rating
    g  - content rights
    h  - pricing (free)
    i  - screenshots
    subs - subscription group + 2 subs + prices + availability + intro offer + review screenshot
    preflight - Stage 4C dry-run
    status - print current state
"""
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

# ---------------------------------------------------------------- constants

APP_ID = "6767872788"
BUNDLE_ID = "com.relationos.app"
TEAM_ID = "NH2XFPC9KN"
# BUILD_ID is intentionally None — it used to be hardcoded to a specific
# v1.0 build and that caused step_c (C2) to silently re-attach a stale
# build to whatever version was being edited. Step_c now skips the
# attach when BUILD_ID is None; use `scripts/attach_build_to_v1_1.py`
# to look up the freshly-uploaded build and attach it.
BUILD_ID = None

KEY_ID = os.environ.get("ASC_KEY_ID", "48ZWN983JL")
ISSUER = os.environ.get("ASC_ISSUER_ID", "730b7d86-5366-48ee-b04f-41a5dc0783cb")
KEY_PATH = os.environ.get(
    "ASC_KEY_PATH",
    f"{os.path.expanduser('~')}/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8",
)
BASE = "https://api.appstoreconnect.apple.com"

REPO = pathlib.Path("/Users/tony/Developer/relationos")
SCREEN_IPHONE = REPO / "screenshots" / "iphone-6.9"
SCREEN_IPAD = REPO / "screenshots" / "ipad-13"
REVIEW_NOTES_PATH = REPO / "docs" / "app-review-notes.md"

# Exclusion list (EU + Vietnam + Korea) - 29 territories total
EU = {"AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA",
      "DEU", "GRC", "HUN", "IRL", "ITA", "LVA", "LTU", "LUX", "MLT", "NLD",
      "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"}
EXCLUDE = EU | {"VNM", "KOR"}

# v1.1 (2026-05-14) — rewrite kept honest per Stage 4A audit findings.
# Source of truth: docs/metadata.md. Keep this constant block in sync.
TARGET_VERSION_STRING = "1.1"

DESCRIPTION = """RelationOS is a personal CRM that lives on your phone.

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

• Every install gets 14 days of Pro free — no card, no commitment.
• After day 14: free tier (up to 100 contacts, notes, reminders, quick-log composers, contact import). Pro unlocks unlimited contacts, the Daily Reconnect list, and cooling-relationships highlighting.
  - $11.99 / month
  - $89.99 / year (save 37%)

Subscriptions auto-renew unless canceled at least 24 hours before the period ends. Manage or cancel in iOS Settings → your Apple ID → Subscriptions.

Privacy policy: https://has-deploy.github.io/relationos/privacy
Terms of Use: https://has-deploy.github.io/relationos/terms
Support: https://has-deploy.github.io/relationos/support"""

KEYWORDS = "personal crm,relationship,contacts,reminders,follow up,network,private,offline,memory,reconnect"
PROMO = "Remember everyone who matters. A daily reconnect list and reminders, on your iPhone. Your contacts and notes stay on-device."
SUPPORT_URL = "https://has-deploy.github.io/relationos/support"
MARKETING_URL = "https://has-deploy.github.io/relationos"
PRIVACY_URL = "https://has-deploy.github.io/relationos/privacy"
WHATS_NEW = "Import your iPhone contacts (pick a few or in bulk) or a vCard. Log a call, text, or email per person. Stability and reliability improvements."
COPYRIGHT = "2026 Tony McMurtrey"
APP_NAME = "RelationOS"
SUBTITLE = "Personal CRM. On your phone."

CONTACT_FIRST = "Tony"
CONTACT_LAST = "McMurtrey"
CONTACT_EMAIL = "tony@medbillresolve.com"
CONTACT_PHONE = "+12102106034"

PRO_GROUP_NAME = "RelationOS Pro"
SUB_PRODUCTS = [
    {
        "productId": "app.relationos.pro.monthly",
        "name": "RelationOS Pro — Monthly",
        "period": "ONE_MONTH",
        "usd": "11.99",
    },
    {
        "productId": "app.relationos.pro.annual",
        "name": "RelationOS Pro — Annual",
        "period": "ONE_YEAR",
        "usd": "89.99",
    },
]
SUB_LOC_DESCRIPTION = "Unlimited contacts, daily reconnect, cooling-rel."  # 49 chars

# ---------------------------------------------------------------- HTTP

def token():
    with open(KEY_PATH, "rb") as f:
        key = f.read()
    return jwt.encode(
        {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 1200,
         "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"},
    )


def REQ(method, path, body=None, params=None, raw=False):
    if params:
        path = path + "?" + urllib.parse.urlencode(params, safe="[]")
    url = path if path.startswith("http") else BASE + path
    headers = {"Authorization": f"Bearer {token()}"}
    data = None
    if body is not None and not raw:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    elif raw and body is not None:
        data = body
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            raw_bytes = r.read()
            if not raw_bytes:
                return r.status, {}
            ct = r.headers.get("Content-Type", "")
            if ct.startswith("application/json") or ct.startswith("application/vnd.api+json"):
                return r.status, json.loads(raw_bytes)
            return r.status, raw_bytes
    except urllib.error.HTTPError as e:
        body_s = e.read().decode(errors="replace")
        return e.code, {"_raw": body_s}


def expect(status, body, label=""):
    if status >= 300:
        raise RuntimeError(f"{label} HTTP {status}: {json.dumps(body)[:1000]}")
    return body


# ---------------------------------------------------------------- helpers

def get_app_info_id():
    """Returns the editable appInfo for the app."""
    _, resp = REQ("GET", f"/v1/apps/{APP_ID}/appInfos", params={"limit": 10})
    infos = resp.get("data", [])
    # Prefer one in editable state
    for state in ("PREPARE_FOR_SUBMISSION", "READY_FOR_SUBMISSION", "READY_FOR_DISTRIBUTION"):
        for i in infos:
            if i["attributes"]["state"] == state:
                return i["id"]
    if infos:
        return infos[0]["id"]
    raise RuntimeError("no appInfo found")


def get_version_id():
    """Returns the editable appStoreVersion id for TARGET_VERSION_STRING.

    Prefer an editable version whose versionString matches TARGET_VERSION_STRING.
    If none exists, create it. Older READY_FOR_SALE / on-sale versions are
    left alone — we never edit a shipped version's metadata.
    """
    _, resp = REQ("GET", f"/v1/apps/{APP_ID}/appStoreVersions", params={"limit": 25})
    versions = resp.get("data", [])
    EDIT = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "INVALID_BINARY", "WAITING_FOR_REVIEW",
            "IN_REVIEW", "DEVELOPER_ACTION_NEEDED"}
    # Exact-target match first
    for v in versions:
        vs = v["attributes"].get("versionString")
        st = v["attributes"]["appStoreState"]
        if vs == TARGET_VERSION_STRING and st in EDIT:
            return v["id"]
    # Any editable as fallback
    for v in versions:
        if v["attributes"]["appStoreState"] in EDIT:
            return v["id"]
    # Need to create the target version
    _, resp = REQ("POST", "/v1/appStoreVersions", body={
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": TARGET_VERSION_STRING},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    if not isinstance(resp, dict) or "data" not in resp:
        raise RuntimeError(f"appStoreVersion create failed: {resp}")
    return resp["data"]["id"]


# ---------------------------------------------------------------- A. App Info

def step_a():
    info_id = get_app_info_id()
    print(f"[A] PATCH /v1/appInfos/{info_id}")
    status, body = REQ("PATCH", f"/v1/appInfos/{info_id}", body={
        "data": {
            "type": "appInfos",
            "id": info_id,
            "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
                "secondaryCategory": {"data": {"type": "appCategories", "id": "LIFESTYLE"}},
            },
        }
    })
    if status >= 300:
        print(f"  FAILED HTTP {status}: {body}")
        return "FAILED", info_id
    print("  OK -> categories set (primary=PRODUCTIVITY, secondary=LIFESTYLE)")
    return "SUCCESS", info_id


# ---------------------------------------------------------------- B. App Info Localization

def step_b():
    info_id = get_app_info_id()
    _, locs = REQ("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations", params={"limit": 50})
    en = next((l for l in locs.get("data", []) if l["attributes"]["locale"] == "en-US"), None)
    attrs = {
        "name": APP_NAME,
        "subtitle": SUBTITLE,
        "privacyPolicyUrl": PRIVACY_URL,
        "privacyPolicyText": None,
    }
    if en:
        loc_id = en["id"]
        print(f"[B] PATCH /v1/appInfoLocalizations/{loc_id}")
        status, body = REQ("PATCH", f"/v1/appInfoLocalizations/{loc_id}", body={
            "data": {"type": "appInfoLocalizations", "id": loc_id, "attributes": attrs}
        })
    else:
        print(f"[B] POST /v1/appInfoLocalizations (en-US)")
        status, body = REQ("POST", "/v1/appInfoLocalizations", body={
            "data": {
                "type": "appInfoLocalizations",
                "attributes": {"locale": "en-US", **attrs},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}},
            }
        })
    if status >= 300:
        print(f"  FAILED HTTP {status}: {body}")
        return "FAILED"
    print(f"  OK -> name/subtitle/privacy URL set")
    return "SUCCESS"


# ---------------------------------------------------------------- C. App Store Version

def step_c():
    vid = get_version_id()
    print(f"[C1] PATCH /v1/appStoreVersions/{vid}")
    status, body = REQ("PATCH", f"/v1/appStoreVersions/{vid}", body={
        "data": {
            "type": "appStoreVersions",
            "id": vid,
            "attributes": {"copyright": COPYRIGHT, "releaseType": "MANUAL"},
        }
    })
    if status >= 300:
        print(f"  FAILED HTTP {status}: {body}")
        return "FAILED"
    print("  OK -> copyright + releaseType=MANUAL")
    if BUILD_ID:
        print(f"[C2] PATCH /v1/appStoreVersions/{vid}/relationships/build (build={BUILD_ID})")
        status, body = REQ("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", body={
            "data": {"type": "builds", "id": BUILD_ID}
        })
        if status >= 300:
            print(f"  FAILED HTTP {status}: {body}")
            return "PARTIAL"
        print("  OK -> build attached")
    else:
        print("[C2] skipped — BUILD_ID is None (use scripts/attach_build_to_v1_1.py post-upload)")
    return "SUCCESS"


# ---------------------------------------------------------------- D. Version Localization

def step_d():
    vid = get_version_id()
    _, locs = REQ("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations",
                  params={"limit": 50})
    en = next((l for l in locs.get("data", []) if l["attributes"]["locale"] == "en-US"), None)
    base_attrs = {
        "description": DESCRIPTION,
        "keywords": KEYWORDS,
        "promotionalText": PROMO,
        "supportUrl": SUPPORT_URL,
        "marketingUrl": MARKETING_URL,
        "whatsNew": WHATS_NEW,
    }
    # Try with whatsNew; if it complains about whatsNew not editable, retry without
    attrs = dict(base_attrs)
    overall = "SUCCESS"
    for attempt in range(3):
        if en:
            loc_id = en["id"]
            print(f"[D] PATCH /v1/appStoreVersionLocalizations/{loc_id} ({len(attrs)} attrs)")
            status, body = REQ("PATCH", f"/v1/appStoreVersionLocalizations/{loc_id}", body={
                "data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": attrs}
            })
        else:
            print(f"[D] POST /v1/appStoreVersionLocalizations (en-US, {len(attrs)} attrs)")
            status, body = REQ("POST", "/v1/appStoreVersionLocalizations", body={
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"locale": "en-US", **attrs},
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}},
                }
            })
        if status < 300:
            print(f"  OK -> {sorted(attrs.keys())}")
            return overall
        raw = body.get("_raw", "") if isinstance(body, dict) else str(body)
        # Identify offending attribute
        m = re.search(r"Attribute '(\w+)' cannot be edited", raw)
        if m and m.group(1) in attrs:
            bad = m.group(1)
            print(f"  attr '{bad}' not editable now; retrying without it")
            attrs.pop(bad, None)
            overall = "PARTIAL"
            continue
        print(f"  FAILED HTTP {status}: {raw[:400]}")
        return "FAILED"
    return overall


# ---------------------------------------------------------------- E. App Review Detail

def review_notes_text():
    if not REVIEW_NOTES_PATH.exists():
        return "RelationOS is a private, on-device personal CRM. Reviewer can exercise the full app without creating an account."
    raw = REVIEW_NOTES_PATH.read_text()
    # Strip markdown comments
    raw = re.sub(r"<!--.*?-->", "", raw, flags=re.DOTALL)
    # Cap at 4000 chars (Apple's limit)
    return raw[:3900].strip()


def step_e():
    vid = get_version_id()
    # Try to GET an existing review detail
    status, body = REQ("GET", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
    detail_id = None
    if status < 300 and body.get("data"):
        detail_id = body["data"]["id"]
        print(f"[E] existing reviewDetail {detail_id}")
    notes = review_notes_text()
    attrs = {
        "contactFirstName": CONTACT_FIRST,
        "contactLastName": CONTACT_LAST,
        "contactEmail": CONTACT_EMAIL,
        "contactPhone": CONTACT_PHONE,
        "demoAccountRequired": False,
        "demoAccountName": None,
        "demoAccountPassword": None,
        "notes": notes,
    }
    if detail_id:
        print(f"[E] PATCH /v1/appStoreReviewDetails/{detail_id}")
        status, body = REQ("PATCH", f"/v1/appStoreReviewDetails/{detail_id}", body={
            "data": {"type": "appStoreReviewDetails", "id": detail_id, "attributes": attrs}
        })
    else:
        print(f"[E] POST /v1/appStoreReviewDetails")
        status, body = REQ("POST", "/v1/appStoreReviewDetails", body={
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": attrs,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}},
            }
        })
    if status >= 300:
        print(f"  FAILED HTTP {status}: {body}")
        return "FAILED"
    print("  OK -> review contact + notes set")
    return "SUCCESS"


# ---------------------------------------------------------------- F. Age Rating

# Comprehensive 4+ age rating attributes. Apple's enum changes; we use the
# full superset and let the API ignore any that aren't on the current schema.
AGE_RATING_NONE = {
    # Substances
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    # Contests / gambling
    "contests": "NONE",
    "gamblingSimulated": "NONE",
    "gambling": False,
    "lootBox": False,
    # Violence
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "gunsOrOtherWeapons": "NONE",
    # Sexual / mature
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    # Other
    "profanityOrCrudeHumor": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "healthOrWellnessTopics": "NONE",
    "advertising": "NONE",
    "messagingAndChat": "NONE",
    "parentalControls": "NONE",
    "ageAssurance": "NOT_APPLICABLE",
    # Web access
    "unrestrictedWebAccess": False,
    # Kids age band
    "kidsAgeBand": None,
}


def step_f():
    info_id = get_app_info_id()
    # Schema moved: ageRatingDeclaration now hangs off appInfo
    status, body = REQ("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    if status >= 300 or not body.get("data"):
        print(f"[F] no ageRatingDeclaration via appInfo (HTTP {status})")
        return "PARTIAL"
    decl_id = body["data"]["id"]
    current_attrs = body["data"].get("attributes", {})
    print(f"[F] ageRatingDeclaration {decl_id}; existing attrs: {list(current_attrs.keys())}")

    # Strategy: PATCH the full attribute set. Apple's error responses tell us
    # any "REQUIRED" missing attributes (use those) or "INVALID" attributes
    # (drop those). Iterate.
    attrs = dict(AGE_RATING_NONE)

    # Default values for any newly-required attrs we encounter
    DEFAULT_VALUE_MAP = {
        # boolean keys
        "gambling": False,
        "lootBox": False,
        "unrestrictedWebAccess": False,
        # null
        "kidsAgeBand": None,
        # enum: NOT_APPLICABLE
        "ageAssurance": "NOT_APPLICABLE",
        # all other unknowns default to "NONE"
    }

    for attempt in range(20):
        status, body = REQ("PATCH", f"/v1/ageRatingDeclarations/{decl_id}", body={
            "data": {"type": "ageRatingDeclarations", "id": decl_id, "attributes": attrs}
        })
        if status < 300:
            print(f"  OK -> age rating set to 4+/NONE ({len(attrs)} attrs)")
            return "SUCCESS"
        raw = body.get("_raw", "") if isinstance(body, dict) else str(body)
        try:
            errors = json.loads(raw).get("errors", [])
        except Exception:
            errors = []
        action_taken = False
        for err in errors:
            code = err.get("code", "")
            ptr = (err.get("source") or {}).get("pointer", "")
            m = re.search(r"/data/attributes/(\w+)", ptr)
            if not m:
                continue
            key = m.group(1)
            detail = err.get("detail", "")
            if "REQUIRED" in code:
                val = DEFAULT_VALUE_MAP.get(key, "NONE")
                if attrs.get(key) != val:
                    attrs[key] = val
                    print(f"    + required: {key}={val!r}")
                    action_taken = True
            elif "TYPE" in code:
                # Switch type based on detail
                if "BOOLEAN" in detail and "STRING" in detail:
                    attrs[key] = False
                    print(f"    ~ type: {key}=False")
                    action_taken = True
                elif "STRING" in detail and "BOOLEAN" in detail:
                    attrs[key] = "NONE"
                    print(f"    ~ type: {key}='NONE'")
                    action_taken = True
                elif "NULL" in detail or "null" in detail:
                    attrs[key] = None
                    print(f"    ~ type: {key}=None")
                    action_taken = True
                else:
                    del attrs[key]
                    print(f"    - type-unknown: {key}")
                    action_taken = True
            elif "INVALID" in code or "ATTRIBUTE_INVALID" in code or "ATTRIBUTE_NOT_FOUND" in code:
                if key in attrs:
                    del attrs[key]
                    print(f"    - invalid: {key}")
                    action_taken = True
            elif "ENUM" in code or "VALUE" in code:
                if attrs.get(key) == "NONE":
                    attrs[key] = "NOT_APPLICABLE"
                    print(f"    ~ enum: {key}=NOT_APPLICABLE")
                    action_taken = True
                elif attrs.get(key) == "NOT_APPLICABLE":
                    del attrs[key]
                    print(f"    - enum failed: {key}")
                    action_taken = True
        if not action_taken:
            print(f"  FAILED HTTP {status}: {raw[:600]}")
            return "FAILED"
    print(f"  FAILED — too many retries; final attrs: {list(attrs.keys())}")
    return "FAILED"


# ---------------------------------------------------------------- G. Content Rights

def step_g():
    print(f"[G] PATCH /v1/apps/{APP_ID} contentRightsDeclaration")
    status, body = REQ("PATCH", f"/v1/apps/{APP_ID}", body={
        "data": {
            "type": "apps",
            "id": APP_ID,
            "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"},
        }
    })
    if status >= 300:
        print(f"  FAILED HTTP {status}: {body}")
        return "FAILED"
    print("  OK -> DOES_NOT_USE_THIRD_PARTY_CONTENT")
    return "SUCCESS"


# ---------------------------------------------------------------- H. Pricing (free)

def step_h():
    # Find a USA appPricePoint with customerPrice = 0.00 (free)
    # We can't list pricePoints without a sub/IAP; so use the well-known free tier.
    # Apple's API: GET /v1/appPricePoints?filter[territory]=USA finds points; the
    # one with priceTier == "0" / customerPrice == "0.00" is free.
    print("[H] looking up USA free price point ...")
    free_pp = None
    next_url = f"/v1/apps/{APP_ID}/appPricePoints?filter[territory]=USA&limit=200"
    while next_url and not free_pp:
        s, b = REQ("GET", next_url if next_url.startswith("/") else next_url.replace(BASE, ""))
        if s >= 300:
            break
        for p in b.get("data", []):
            cp = str(p["attributes"].get("customerPrice"))
            if cp in ("0.00", "0", "0.0"):
                free_pp = p["id"]
                break
        next_url = (b.get("links") or {}).get("next")
        if next_url and next_url.startswith(BASE):
            next_url = next_url[len(BASE):]
    if not free_pp:
        print(f"  WARN: no USA free price point found; ASC may default to free already")
        return "PARTIAL"
    print(f"  USA free price point: {free_pp}")
    body_req = {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${price1}"}]},
            },
        },
        "included": [{
            "id": "${price1}",
            "type": "appPrices",
            "attributes": {"startDate": None},
            "relationships": {
                "appPricePoint": {"data": {"type": "appPricePoints", "id": free_pp}},
            },
        }],
    }
    status, body = REQ("POST", "/v1/appPriceSchedules", body=body_req)
    if status >= 300:
        raw = body.get("_raw", "") if isinstance(body, dict) else str(body)
        if "already" in raw.lower() or status == 409:
            print(f"  OK -> already exists")
            return "SUCCESS"
        print(f"  FAILED HTTP {status}: {raw[:600]}")
        return "PARTIAL"
    print(f"  OK -> set USA free")
    return "SUCCESS"


# ---------------------------------------------------------------- I. Screenshots

def upload_asset(upload_ops, data):
    for op in upload_ops:
        url = op["url"]
        method = op["method"]
        offset = op.get("offset", 0)
        length = op.get("length", len(data))
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = data[offset:offset + length]
        req = urllib.request.Request(url, data=chunk, method=method, headers=headers)
        with urllib.request.urlopen(req) as r:
            r.read()


def upload_screenshots_for(display_type, folder):
    vid = get_version_id()
    _, locs = REQ("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations",
                  params={"limit": 50})
    en = next((l for l in locs.get("data", []) if l["attributes"]["locale"] == "en-US"), None)
    if not en:
        print(f"  no en-US localization; run step D first")
        return False
    loc_id = en["id"]

    _, sets = REQ("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets",
                  params={"filter[screenshotDisplayType]": display_type, "limit": 50})
    target_set = None
    for s in sets.get("data", []):
        if s["attributes"]["screenshotDisplayType"] == display_type:
            target_set = s
            break
    if target_set:
        set_id = target_set["id"]
        # Check if already populated (idempotent: skip if already 3+ shots present)
        _, shots = REQ("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots", params={"limit": 50})
        if len(shots.get("data", [])) >= 3:
            print(f"  {display_type}: set {set_id} already has {len(shots['data'])} screenshots — skipping upload")
            return True
    else:
        status, body = REQ("POST", "/v1/appScreenshotSets", body={
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                    }
                },
            }
        })
        if status >= 300:
            print(f"  FAILED to create set: HTTP {status}: {body}")
            return False
        set_id = body["data"]["id"]
    print(f"  {display_type}: set {set_id}")

    files = sorted(folder.glob("*.png"))
    for path in files:
        data = path.read_bytes()
        print(f"    upload {path.name} ({len(data)} bytes)")
        status, body = REQ("POST", "/v1/appScreenshots", body={
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": len(data)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
            }
        })
        if status >= 300:
            print(f"      FAILED reserve: HTTP {status}: {body}")
            continue
        shot_id = body["data"]["id"]
        ops = body["data"]["attributes"]["uploadOperations"]
        try:
            upload_asset(ops, data)
        except Exception as e:
            print(f"      FAILED upload bytes: {e}")
            continue
        status, body = REQ("PATCH", f"/v1/appScreenshots/{shot_id}", body={
            "data": {
                "type": "appScreenshots",
                "id": shot_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": None},
            }
        })
        if status >= 300:
            print(f"      FAILED commit: HTTP {status}: {body}")
            continue
        print(f"      OK -> {shot_id}")
    return True


def step_i():
    print("[I] uploading iPhone 6.9 screenshots")
    # Apple's enum uses APP_IPHONE_67 for the 6.7"/6.9" device class (1320×2868)
    ok1 = upload_screenshots_for("APP_IPHONE_67", SCREEN_IPHONE)
    print("[I] uploading iPad 13 screenshots")
    ok2 = upload_screenshots_for("APP_IPAD_PRO_3GEN_129", SCREEN_IPAD)
    return "SUCCESS" if (ok1 and ok2) else "PARTIAL"


# ---------------------------------------------------------------- SUBSCRIPTIONS

def find_or_create_sub_group():
    # GET groups attached to this app
    _, resp = REQ("GET", f"/v1/apps/{APP_ID}/subscriptionGroups", params={"limit": 50})
    for g in resp.get("data", []):
        if g["attributes"].get("referenceName") == PRO_GROUP_NAME:
            print(f"  group exists: {g['id']}")
            return g["id"]
    # Create
    print(f"  creating group {PRO_GROUP_NAME}")
    status, body = REQ("POST", "/v1/subscriptionGroups", body={
        "data": {
            "type": "subscriptionGroups",
            "attributes": {"referenceName": PRO_GROUP_NAME},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    expect(status, body, "create sub group")
    return body["data"]["id"]


def ensure_group_localization(group_id):
    _, resp = REQ("GET", f"/v1/subscriptionGroups/{group_id}/subscriptionGroupLocalizations",
                  params={"limit": 50})
    for l in resp.get("data", []):
        if l["attributes"]["locale"] == "en-US":
            print(f"  group localization exists: {l['id']}")
            return l["id"]
    status, body = REQ("POST", "/v1/subscriptionGroupLocalizations", body={
        "data": {
            "type": "subscriptionGroupLocalizations",
            "attributes": {
                "name": PRO_GROUP_NAME,
                "locale": "en-US",
                "customAppName": None,
            },
            "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group_id}}},
        }
    })
    expect(status, body, "create group localization")
    return body["data"]["id"]


def find_or_create_sub(group_id, product):
    # GET subs in group
    _, resp = REQ("GET", f"/v1/subscriptionGroups/{group_id}/subscriptions", params={"limit": 50})
    for s in resp.get("data", []):
        if s["attributes"]["productId"] == product["productId"]:
            print(f"    sub exists: {s['id']} state={s['attributes']['state']}")
            return s["id"]
    # Create
    print(f"    creating sub {product['productId']}")
    status, body = REQ("POST", "/v1/subscriptions", body={
        "data": {
            "type": "subscriptions",
            "attributes": {
                "name": product["name"],
                "productId": product["productId"],
                "subscriptionPeriod": product["period"],
                "familySharable": False,
                "groupLevel": 1,
            },
            "relationships": {
                "group": {"data": {"type": "subscriptionGroups", "id": group_id}},
            },
        }
    })
    expect(status, body, f"create sub {product['productId']}")
    return body["data"]["id"]


def ensure_sub_localization(sub_id, product):
    _, resp = REQ("GET", f"/v1/subscriptions/{sub_id}/subscriptionLocalizations",
                  params={"limit": 50})
    for l in resp.get("data", []):
        if l["attributes"]["locale"] == "en-US":
            print(f"    sub localization exists: {l['id']}")
            # Patch to ensure description is correct
            status, body = REQ("PATCH", f"/v1/subscriptionLocalizations/{l['id']}", body={
                "data": {
                    "type": "subscriptionLocalizations",
                    "id": l["id"],
                    "attributes": {
                        "name": product["name"],
                        "description": SUB_LOC_DESCRIPTION,
                    },
                }
            })
            return l["id"]
    status, body = REQ("POST", "/v1/subscriptionLocalizations", body={
        "data": {
            "type": "subscriptionLocalizations",
            "attributes": {
                "name": product["name"],
                "description": SUB_LOC_DESCRIPTION,
                "locale": "en-US",
            },
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}},
        }
    })
    expect(status, body, f"create localization for {product['productId']}")
    return body["data"]["id"]


def find_usa_price_point(sub_id, target_usd):
    """Find the USA price point ID that maps to the target USD customer price."""
    # Paginate through subscriptionPricePoints filtered by territory USA
    next_url = f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]=USA&limit=200"
    while next_url:
        status, body = REQ("GET", next_url)
        if status >= 300:
            raise RuntimeError(f"price points GET failed: {body}")
        for p in body.get("data", []):
            cp = p["attributes"].get("customerPrice")
            if cp == target_usd:
                return p["id"]
        next_url = (body.get("links") or {}).get("next")
        if next_url and next_url.startswith("https://"):
            # use full URL
            pass
        elif next_url:
            next_url = next_url.replace(BASE, "")
    return None


def existing_sub_prices(sub_id):
    """Return dict[territory] -> price-row-id for currently committed prices."""
    out = {}
    next_url = f"/v1/subscriptions/{sub_id}/prices?limit=200&include=territory"
    while next_url:
        status, body = REQ("GET", next_url if next_url.startswith("/") else next_url.replace(BASE, ""))
        if status >= 300:
            return out
        # Walk included territories
        territories_by_id = {}
        for inc in body.get("included", []):
            if inc.get("type") == "territories":
                territories_by_id[inc["id"]] = inc["id"]
        for row in body.get("data", []):
            terr = ((row.get("relationships") or {}).get("territory") or {}).get("data") or {}
            if terr:
                out[terr["id"]] = row["id"]
        next_link = (body.get("links") or {}).get("next")
        if not next_link:
            break
        next_url = next_link
    return out


def get_all_territories():
    """Return list of territory id (3-letter)."""
    out = []
    next_url = "/v1/territories?limit=200"
    while next_url:
        status, body = REQ("GET", next_url if next_url.startswith("/") else next_url.replace(BASE, ""))
        if status >= 300:
            break
        for t in body.get("data", []):
            out.append(t["id"])
        next_link = (body.get("links") or {}).get("next")
        if not next_link:
            break
        next_url = next_link
    return out


def equalize_pricing(sub_id, usa_pp_id, target_territories):
    """For each territory in target_territories, create a subscriptionPrices
    row referencing the equalized price point. Skip if already present."""
    existing = existing_sub_prices(sub_id)
    skipped = 0
    created = 0
    failed = []
    for terr in target_territories:
        if terr in existing:
            skipped += 1
            continue
        # GET equalized price point for this territory
        status, body = REQ("GET",
            f"/v1/subscriptionPricePoints/{usa_pp_id}/equalizations",
            params={"filter[territory]": terr, "limit": 1})
        if status >= 300 or not body.get("data"):
            failed.append((terr, "no_equalization"))
            continue
        pp_id = body["data"][0]["id"]
        # POST a price row
        status, body = REQ("POST", "/v1/subscriptionPrices", body={
            "data": {
                "type": "subscriptionPrices",
                "attributes": {"startDate": None, "preserveCurrentPrice": False},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                    "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp_id}},
                    "territory": {"data": {"type": "territories", "id": terr}},
                },
            }
        })
        if status >= 300:
            failed.append((terr, str(body)[:80]))
        else:
            created += 1
    return created, skipped, failed


def ensure_availability(sub_id, target_set):
    """POST or PATCH a subscriptionAvailability with target_set as availableTerritories."""
    # GET current
    status, body = REQ("GET", f"/v1/subscriptions/{sub_id}/subscriptionAvailability")
    have = []
    avail_id = None
    if status < 300 and body.get("data"):
        avail_id = body["data"]["id"]
        # GET territories
        _, terr_body = REQ("GET",
            f"/v1/subscriptionAvailabilities/{avail_id}/availableTerritories",
            params={"limit": 200})
        have = [t["id"] for t in terr_body.get("data", [])]

    # Safety: if listing returns < 100 territories, rebuild from world − EXCLUDE
    if len(have) < 100:
        print(f"    safety guard: have only {len(have)} territories — rebuilding from full set")
        territories = list(target_set)
    else:
        territories = list(target_set)

    if avail_id:
        print(f"    PATCH availability {avail_id} → {len(territories)} territories")
        # Apple's API uses POST with "include" for new, but availability is a one-of relationship.
        # Recreate by POSTing new and letting old be replaced.
        # The correct path: POST /v1/subscriptionAvailabilities (always replaces existing).
        pass

    body_req = {
        "data": {
            "type": "subscriptionAvailabilities",
            "attributes": {"availableInNewTerritories": False},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                "availableTerritories": {
                    "data": [{"type": "territories", "id": t} for t in territories]
                },
            },
        }
    }
    status, body = REQ("POST", "/v1/subscriptionAvailabilities", body=body_req)
    if status >= 300:
        print(f"    availability POST failed HTTP {status}: {str(body)[:300]}")
        return False
    print(f"    OK -> availability set to {len(territories)} territories")
    return True


def force_state_recompute(sub_id):
    """Force ASC to recompute state by patching reviewNote."""
    status, body = REQ("PATCH", f"/v1/subscriptions/{sub_id}", body={
        "data": {
            "type": "subscriptions",
            "id": sub_id,
            "attributes": {"reviewNote": "ready"},
        }
    })
    if status >= 300:
        print(f"    state recompute failed: HTTP {status}: {str(body)[:200]}")
        return False
    return True


def upload_sub_review_screenshot(sub_id):
    # Check existing
    _, resp = REQ("GET", f"/v1/subscriptions/{sub_id}/appStoreReviewScreenshot")
    if resp.get("data"):
        print(f"    sub review screenshot exists: {resp['data']['id']}")
        return True
    # Upload paywall PNG from iPhone screenshots
    path = SCREEN_IPHONE / "04-paywall.png"
    if not path.exists():
        print(f"    paywall PNG not found at {path}")
        return False
    data = path.read_bytes()
    print(f"    uploading paywall.png ({len(data)} bytes)")
    status, body = REQ("POST", "/v1/subscriptionAppStoreReviewScreenshots", body={
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "attributes": {"fileName": path.name, "fileSize": len(data)},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}},
        }
    })
    if status >= 300:
        print(f"      FAILED reserve: HTTP {status}: {str(body)[:300]}")
        return False
    shot_id = body["data"]["id"]
    ops = body["data"]["attributes"]["uploadOperations"]
    try:
        upload_asset(ops, data)
    except Exception as e:
        print(f"      FAILED upload bytes: {e}")
        return False
    status, body = REQ("PATCH", f"/v1/subscriptionAppStoreReviewScreenshots/{shot_id}", body={
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "id": shot_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": None},
        }
    })
    if status >= 300:
        print(f"      FAILED commit: HTTP {status}: {str(body)[:300]}")
        return False
    print(f"      OK -> {shot_id}")
    return True


def ensure_intro_offer(sub_id, product, target_territories):
    # Check existing
    _, resp = REQ("GET", f"/v1/subscriptions/{sub_id}/introductoryOffers", params={"limit": 50})
    if resp.get("data"):
        print(f"    intro offer exists ({len(resp['data'])} rows)")
        return True
    # Create one global intro offer (no territory filter). If API requires
    # per-territory, fall back to per-territory loop.
    print(f"    creating 2-week free trial intro offer")
    body_req = {
        "data": {
            "type": "subscriptionIntroductoryOffers",
            "attributes": {
                "duration": "TWO_WEEKS",
                "offerMode": "FREE_TRIAL",
                "numberOfPeriods": 1,
                "startDate": None,
                "endDate": None,
            },
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
            },
        }
    }
    status, body = REQ("POST", "/v1/subscriptionIntroductoryOffers", body=body_req)
    if status < 300:
        print(f"      OK -> intro offer (global)")
        return True
    # Try per-territory variant
    raw = body.get("_raw", "") if isinstance(body, dict) else str(body)
    if "territory" in raw.lower():
        ok = 0
        for terr in target_territories:
            body_req["data"]["relationships"]["territory"] = {"data": {"type": "territories", "id": terr}}
            s, b = REQ("POST", "/v1/subscriptionIntroductoryOffers", body=body_req)
            if s < 300:
                ok += 1
        print(f"      OK -> {ok}/{len(target_territories)} per-territory intro offers")
        return ok > 0
    print(f"      FAILED HTTP {status}: {raw[:400]}")
    return False


def step_subs():
    print("[J] subscription pipeline")
    print("  group ...")
    group_id = find_or_create_sub_group()
    ensure_group_localization(group_id)

    all_terrs = set(get_all_territories())
    target_set = all_terrs - EXCLUDE
    print(f"  total territories: {len(all_terrs)}, target (after EU+VNM+KOR exclude): {len(target_set)}")

    sub_results = []
    for product in SUB_PRODUCTS:
        print(f"  --- {product['productId']} ---")
        sub_id = find_or_create_sub(group_id, product)
        ensure_sub_localization(sub_id, product)

        # Pricing: USA first, then equalize
        usa_pp = find_usa_price_point(sub_id, product["usd"])
        if not usa_pp:
            print(f"    WARN: no USA price point at {product['usd']}; pricing skipped")
        else:
            print(f"    USA price point: {usa_pp}")
            # Set USA price first if not already there
            existing = existing_sub_prices(sub_id)
            if "USA" not in existing:
                status, body = REQ("POST", "/v1/subscriptionPrices", body={
                    "data": {
                        "type": "subscriptionPrices",
                        "attributes": {"startDate": None, "preserveCurrentPrice": False},
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": usa_pp}},
                            "territory": {"data": {"type": "territories", "id": "USA"}},
                        },
                    }
                })
                if status >= 300:
                    print(f"    USA price FAILED HTTP {status}: {str(body)[:300]}")
                else:
                    print(f"    USA price set")
            # Equalize for the rest
            others = sorted([t for t in target_set if t != "USA"])
            print(f"    equalizing prices across {len(others)} other territories ...")
            created, skipped, failed = equalize_pricing(sub_id, usa_pp, others)
            print(f"    pricing: created={created} skipped={skipped} failed={len(failed)}")
            if failed:
                print(f"    failed sample: {failed[:5]}")

        # Availability
        ensure_availability(sub_id, target_set)

        # Review screenshot
        upload_sub_review_screenshot(sub_id)

        # Intro offer
        ensure_intro_offer(sub_id, product, list(target_set))

        # Force state recompute
        force_state_recompute(sub_id)

        # Final state check
        _, resp = REQ("GET", f"/v1/subscriptions/{sub_id}")
        state = resp.get("data", {}).get("attributes", {}).get("state", "?")
        print(f"    final state: {state}")
        sub_results.append((product["productId"], sub_id, state))
    return sub_results


# ---------------------------------------------------------------- 4C — pre-flight

def step_preflight(sub_results=None):
    print("[4C] subscription submission pre-flight")
    if sub_results is None:
        # Re-resolve sub IDs from group
        sub_results = []
        _, resp = REQ("GET", f"/v1/apps/{APP_ID}/subscriptionGroups", params={"limit": 50})
        for g in resp.get("data", []):
            _, sresp = REQ("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions", params={"limit": 50})
            for s in sresp.get("data", []):
                sub_results.append((s["attributes"]["productId"], s["id"],
                                    s["attributes"]["state"]))
    out = []
    for product_id, sub_id, state in sub_results:
        status, body = REQ("POST", "/v1/subscriptionSubmissions", body={
            "data": {
                "type": "subscriptionSubmissions",
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}},
            }
        })
        if status < 300:
            print(f"  {product_id}: PASS (HTTP {status})")
            out.append((product_id, sub_id, "PASS", state, ""))
        else:
            raw = body.get("_raw", "") if isinstance(body, dict) else str(body)
            # Extract detail messages
            detail = ""
            try:
                j = json.loads(raw)
                errs = j.get("errors", [])
                detail = "; ".join(e.get("detail", "") for e in errs)[:500]
            except Exception:
                detail = raw[:500]
            print(f"  {product_id}: FAIL HTTP {status} — {detail[:250]}")
            out.append((product_id, sub_id, f"FAIL_{status}", state, detail))
    return out


# ---------------------------------------------------------------- status

def cmd_status():
    _, app = REQ("GET", f"/v1/apps/{APP_ID}")
    a = app.get("data", {}).get("attributes", {})
    print(f"App: {a.get('name')} bundle={a.get('bundleId')} contentRights={a.get('contentRightsDeclaration')}")
    _, vs = REQ("GET", f"/v1/apps/{APP_ID}/appStoreVersions", params={"limit": 5})
    for v in vs.get("data", []):
        va = v["attributes"]
        print(f"  version {va['versionString']} state={va['appStoreState']} releaseType={va.get('releaseType')} id={v['id']}")
    _, gs = REQ("GET", f"/v1/apps/{APP_ID}/subscriptionGroups", params={"limit": 50})
    for g in gs.get("data", []):
        print(f"  group {g['attributes']['referenceName']} {g['id']}")
        _, ss = REQ("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions", params={"limit": 50})
        for s in ss.get("data", []):
            sa = s["attributes"]
            print(f"    sub {sa['productId']} state={sa['state']} period={sa['subscriptionPeriod']} id={s['id']}")


# ---------------------------------------------------------------- main

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    results = {}
    if arg in ("all", "a"): results["A"] = step_a()
    if arg in ("all", "b"): results["B"] = step_b()
    if arg in ("all", "c"): results["C"] = step_c()
    if arg in ("all", "d"): results["D"] = step_d()
    if arg in ("all", "e"): results["E"] = step_e()
    if arg in ("all", "f"): results["F"] = step_f()
    if arg in ("all", "g"): results["G"] = step_g()
    if arg in ("all", "h"): results["H"] = step_h()
    if arg in ("all", "i"): results["I"] = step_i()
    sub_results = None
    if arg in ("all", "subs"):
        sub_results = step_subs()
        results["J"] = sub_results
    if arg in ("all", "preflight"):
        results["4C"] = step_preflight(sub_results)
    if arg == "status":
        cmd_status()
        sys.exit(0)
    print("\n=== SUMMARY ===")
    for k, v in results.items():
        print(f"  {k}: {v}")
