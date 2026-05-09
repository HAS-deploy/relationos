# RelationOS

iOS app for **RelationOS** — a private, on-device personal CRM and
relationship-intelligence app for iPhone.

- Locked product spec: [`docs/spec.md`](docs/spec.md)
- Apple review risk profile: [`docs/apple-review-risk-profile.md`](docs/apple-review-risk-profile.md)
- ASC metadata: [`docs/metadata.md`](docs/metadata.md)
- App Privacy answers: [`docs/app-privacy-answers.md`](docs/app-privacy-answers.md)

## Build

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd ~/Developer/relationos
xcodegen generate
xcodebuild -project RelationOS.xcodeproj \
           -scheme RelationOS \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
           test
```

## Privacy posture

- No third-party SDK dependencies. Apple frameworks only.
- No analytics that send data off-device.
- All user data on-device. No cloud sync in v1.
