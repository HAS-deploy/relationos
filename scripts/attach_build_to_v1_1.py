#!/usr/bin/env python3
"""Wait for the most-recently-uploaded build of RelationOS to finish
processing, then attach it to v1.1 (id 364f9674-fd15-458a-b036-7b191ddec62b).

Usage:
    python3 scripts/attach_build_to_v1_1.py
"""
import sys
import time

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from asc_stage7 import REQ, APP_ID, TARGET_VERSION_STRING  # noqa: E402

V1_1_ID = "364f9674-fd15-458a-b036-7b191ddec62b"


def newest_processed_build():
    """Return (build_id, version, processing_state) for the newest build of
    versionString == TARGET_VERSION_STRING. None if nothing yet."""
    rs, body = REQ(
        "GET",
        "/v1/builds",
        params={
            "filter[app]": APP_ID,
            "filter[preReleaseVersion.version]": TARGET_VERSION_STRING,
            "sort": "-uploadedDate",
            "limit": 5,
        },
    )
    if rs >= 300:
        print(f"  GET /v1/builds failed: {body}")
        return None
    for b in body.get("data", []):
        a = b["attributes"]
        return b["id"], a.get("version"), a.get("processingState")
    return None


def main():
    print(f"Waiting for build of v{TARGET_VERSION_STRING} to finish processing…")
    deadline = time.time() + 60 * 30  # 30 min
    while time.time() < deadline:
        hit = newest_processed_build()
        if hit:
            bid, ver, state = hit
            print(f"  build={bid} build#={ver} state={state}")
            if state == "VALID":
                print("  -> attaching to v1.1")
                rs, body = REQ(
                    "PATCH",
                    f"/v1/appStoreVersions/{V1_1_ID}/relationships/build",
                    body={"data": {"type": "builds", "id": bid}},
                )
                if rs < 300:
                    print(f"  attached. v1.1 now references build {bid}.")
                    return 0
                print(f"  attach failed status={rs} body={body}")
                return 2
            if state in {"FAILED", "INVALID"}:
                print(f"  build state={state}; abort.")
                return 3
        time.sleep(30)
    print("  timed out; build never reached VALID.")
    return 4


if __name__ == "__main__":
    sys.exit(main())
