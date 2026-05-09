#!/usr/bin/env python3
"""Apple's pre-flight wants prices for ALL 175 territories, even the ones
we exclude from availability. Fill in EU + KOR + VNM."""
import sys
sys.path.insert(0, '/Users/tony/Developer/relationos/scripts')
from asc_stage7 import REQ, find_usa_price_point, existing_sub_prices, EXCLUDE

SUB_TARGETS = [
    ("app.relationos.pro.monthly", "6767878255", "11.99"),
    ("app.relationos.pro.annual",  "6767879851", "89.99"),
]


def fill(sub_id, usa_pp, territories):
    existing = existing_sub_prices(sub_id)
    created, skipped, failed = 0, 0, []
    for terr in territories:
        if terr in existing:
            skipped += 1
            continue
        s, b = REQ("GET",
            f"/v1/subscriptionPricePoints/{usa_pp}/equalizations",
            params={"filter[territory]": terr, "limit": 1})
        if s >= 300 or not b.get("data"):
            failed.append((terr, "no_eq"))
            continue
        pp_id = b["data"][0]["id"]
        s, b = REQ("POST", "/v1/subscriptionPrices", body={
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
        if s >= 300:
            failed.append((terr, str(b)[:100]))
        else:
            created += 1
    return created, skipped, failed


for product_id, sub_id, usd in SUB_TARGETS:
    print(f"\n=== {product_id} ===")
    usa_pp = find_usa_price_point(sub_id, usd)
    targets = sorted(EXCLUDE)
    print(f"  filling {len(targets)} territories")
    created, skipped, failed = fill(sub_id, usa_pp, targets)
    print(f"  created={created} skipped={skipped} failed={len(failed)}")
    if failed:
        print(f"  failed: {failed}")
    existing = existing_sub_prices(sub_id)
    print(f"  total prices: {len(existing)}")
