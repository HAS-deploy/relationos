#!/usr/bin/env python3
"""Run pricing across territories for both subs (idempotent)."""
import sys
sys.path.insert(0, '/Users/tony/Developer/relationos/scripts')
from asc_stage7 import (
    REQ, find_usa_price_point, existing_sub_prices,
    EXCLUDE, get_all_territories, force_state_recompute, BASE
)
import urllib.error

SUB_TARGETS = [
    ("app.relationos.pro.monthly", "6767878255", "11.99"),
    ("app.relationos.pro.annual",  "6767879851", "89.99"),
]


def equalize(sub_id, usa_pp, territories):
    existing = existing_sub_prices(sub_id)
    print(f"  existing: {len(existing)} prices")
    created = 0
    skipped = 0
    failed = []
    for terr in territories:
        if terr in existing:
            skipped += 1
            continue
        # Get equalized price point
        s, b = REQ("GET",
            f"/v1/subscriptionPricePoints/{usa_pp}/equalizations",
            params={"filter[territory]": terr, "limit": 1})
        if s >= 300 or not b.get("data"):
            failed.append((terr, "no_equalization"))
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
            raw = b.get("_raw", "") if isinstance(b, dict) else str(b)
            failed.append((terr, raw[:100]))
        else:
            created += 1
    return created, skipped, failed


def main():
    all_terrs = set(get_all_territories())
    target = sorted(all_terrs - EXCLUDE)
    print(f"target: {len(target)} territories")
    for product_id, sub_id, usd in SUB_TARGETS:
        print(f"\n=== {product_id} ({sub_id}) target=${usd} ===")
        usa_pp = find_usa_price_point(sub_id, usd)
        if not usa_pp:
            print(f"  no USA price point at {usd}")
            continue
        print(f"  USA pp: {usa_pp}")
        # Ensure USA exists
        existing = existing_sub_prices(sub_id)
        if "USA" not in existing:
            s, b = REQ("POST", "/v1/subscriptionPrices", body={
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
            if s < 300:
                print("  USA price set")
            else:
                print(f"  USA price FAILED HTTP {s}: {str(b)[:300]}")
        # Equalize for the rest
        others = [t for t in target if t != "USA"]
        created, skipped, failed = equalize(sub_id, usa_pp, others)
        print(f"  pricing result: created={created} skipped={skipped} failed={len(failed)}")
        if failed:
            print(f"  failed sample: {failed[:5]}")
        # Final
        existing = existing_sub_prices(sub_id)
        print(f"  total prices on sub: {len(existing)}")
        # Force recompute
        force_state_recompute(sub_id)


if __name__ == "__main__":
    main()
