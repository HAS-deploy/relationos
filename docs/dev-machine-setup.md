# Dev machine — restore from a fresh reboot or new Mac

The build env for RelationOS depends on Xcode, an iOS platform install, ASC API credentials, Python deps, and a few CLI tools. This is what to put back if a reboot or a fresh install drops them. Most items survive reboot just fine — the ones that don't are flagged with **does NOT survive reboot**.

## What survives a reboot

- Xcode.app and its bundled iOS device SDK (`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk`).
- Installed iOS Simulator runtimes under `/Library/Developer/CoreSimulator/Profiles/Runtimes/`.
- App Store Connect API key at `~/.appstoreconnect/private_keys/AuthKey_48ZWN983JL.p8`.
- The xcodegen-generated `.xcodeproj` and its package graph (Xcode regenerates SwiftPM checkouts on demand).
- Provisioning profiles in `~/Library/MobileDevice/Provisioning Profiles/` (Apple Distribution: "RelationOS App Store" + "RelationOS Widgets App Store").
- The signing identity in your login keychain (`Apple Distribution: anthony mcmurtrey (NH2XFPC9KN)`, SHA-1 `C786E7CC218F869D79E7BF21485D164C480B15B0`).
- The git repo at `~/Developer/relationos` and the gh-pages worktree.

## What does NOT survive a reboot

- **Any background process I started in a shell** (`nohup xcodebuild -downloadPlatform iOS`, `simctl boot`, `mobileassetd`-driven downloads, watchers waiting on log files). These are local processes. Re-arm with the commands below.
- **Booted simulators.** `xcrun simctl list devices booted` will be empty. Re-boot the one you want.
- **Cached SwiftPM checkouts** in `~/Library/Caches/org.swift.swiftpm/`. They get repopulated on next `xcodebuild`, but the first run after reboot is slow.
- **Background watchers I'd armed in Claude Code** (`b691dg96e` etc.). The chat thread persists; the local watchers do not. I have to re-arm them when you say to resume.

## Restore steps (most common cases)

### After a reboot, mid-ship

```sh
cd ~/Developer/relationos

# 1. Confirm Xcode + SDK + signing identity are intact.
xcodebuild -version
xcodebuild -showsdks | grep iphoneos
security find-identity -p codesigning -v | grep "Apple Distribution"
# Should see Xcode 26.x, iphoneos26.x, the C786…B15B0 identity.

# 2. Confirm the iOS device platform support is still installed.
xcodebuild -project RelationOS.xcodeproj -scheme RelationOS -showdestinations 2>&1 \
  | grep -E "platform:iOS|iOS [0-9]+\.[0-9]+ is not installed"
# If you see "iOS 26.x is not installed", open Xcode → Settings → Platforms → click Get on iOS.
# CLI workaround (slow, partial — installs the simulator runtime not the device support files):
#   xcodebuild -downloadPlatform iOS

# 3. Check the v1.1 ASC state.
python3 scripts/asc_stage7.py status
# Expect: version 1.1 in PREPARE_FOR_SUBMISSION (or whatever state we'd left it in),
# build 5 attached, both subs with 0 introductory offers.

# 4. Resume from wherever I left off (see ~/Developer/relationos/scripts/ship_v1_1.sh
#    for the canonical archive → export → upload → attach pipeline).
```

### After a fresh OS install or new Mac

In addition to the above:

```sh
# Install Xcode from the Mac App Store.
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch

# Install the iOS device platform support
#   (Xcode → Settings → Platforms → iOS → Get,
#    OR `xcodebuild -downloadPlatform iOS` for the simulator runtime).

# Install xcodegen if not present
brew install xcodegen

# Drop the ASC API key in place
mkdir -p ~/.appstoreconnect/private_keys
# Move AuthKey_48ZWN983JL.p8 into that dir (stored in 1Password / your backup).

# Add the Apple Distribution signing identity + provisioning profiles
# (export from the old Mac via Keychain Access or use Xcode Settings → Accounts → Manage Certificates).

# Verify everything is wired
xcodebuild -version
xcrun altool --validate-app -f some.ipa -t ios --apiKey 48ZWN983JL \
  --apiIssuer 730b7d86-5366-48ee-b04f-41a5dc0783cb 2>&1 | head -3
```

## ASC credentials

| Item | Value |
|---|---|
| App ID | `6767872788` |
| Bundle ID | `com.relationos.app` |
| Team ID | `NH2XFPC9KN` |
| ASC Key ID | `48ZWN983JL` (env: `ASC_KEY_ID`) |
| ASC Issuer ID | `730b7d86-5366-48ee-b04f-41a5dc0783cb` (env: `ASC_ISSUER_ID`) |
| Key path | `~/.appstoreconnect/private_keys/AuthKey_48ZWN983JL.p8` (env: `ASC_KEY_PATH`) |
| Subscription monthly | `app.relationos.pro.monthly` (id `6767878255`) |
| Subscription annual | `app.relationos.pro.annual` (id `6767879851`) |
| Subscription group | `RelationOS Pro` (id `22078011`) |

## Current ship state (snapshot)

> Update this section whenever the ship state changes substantially.

- **Live App Store version:** v1.0 (id `2ca64bc8-ae89-4c5d-9833-b27ebf6ba154`), READY_FOR_SALE, releaseType=MANUAL.
- **In review queue:** v1.1 (id `364f9674-fd15-458a-b036-7b191ddec62b`) with build 5 (id `75ebc095-6841-43a9-bed8-937b9dadeefb`) attached, in PREPARE_FOR_SUBMISSION.
- **Subscriptions:** both APPROVED, zero introductory offers (the 14-day Pro period is an install-grant in app code, see `Core/Purchases/IntroTrialClock.swift`).
- **Remaining hard blockers before tapping Submit:**
  1. Re-shoot all 5 screenshots × 2 device sizes from a Release build of v1.1 b5. The current ones show stale paywall copy + DEBUG section + Version 1.0.
  2. Per-subscription review screenshot uploaded via `subscriptionAppStoreReviewScreenshots`.
  3. ASC App Privacy nutrition answers confirmed in the web UI (Product Interaction + Crash + Performance + Other Diagnostic, all linked=NO, tracking=NO — matches `PrivacyInfo.xcprivacy`).
