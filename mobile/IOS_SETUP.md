# iOS Setup

This project is prepared for iOS, but the final build still needs macOS with Xcode.

## Current project settings

- App name: `SafarUz`
- Bundle identifier: `uz.safaruz.mobile`
- Minimum iOS version: `13.0`
- Firebase packages are already included in Flutter dependencies
- iOS local notifications and foreground push presentation are enabled in code

## Files you must add on macOS

1. `mobile/ios/Runner/GoogleService-Info.plist`
   - Create an iOS app in Firebase with bundle id `uz.safaruz.mobile`
   - Download `GoogleService-Info.plist`
   - Put it into `mobile/ios/Runner/`

## Xcode steps

1. Open:
   - `mobile/ios/Runner.xcworkspace`

2. In `Runner` target:
   - `Signing & Capabilities`
   - Choose your Apple team
   - Confirm bundle id is `uz.safaruz.mobile`

3. Add capabilities:
   - `Push Notifications`
   - `Background Modes`
   - Enable:
     - `Remote notifications`
     - `Background fetch`

4. In Firebase console:
   - Open project settings
   - Add iOS app with bundle id `uz.safaruz.mobile`
   - Upload APNs auth key or certificates for Cloud Messaging

## First-time macOS commands

Run these from `mobile/`:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release
```

For simulator testing:

```bash
flutter run -d ios
```

## Release checklist

- `GoogleService-Info.plist` added locally
- Apple signing team selected
- Push Notifications capability enabled
- Background Modes enabled
- APNs key linked in Firebase
- Device tested for:
  - login
  - OTP flow
  - password flow
  - push notifications in foreground/background
  - Telegram support links

## Notes

- `GoogleService-Info.plist` is ignored by git on purpose.
- Final TestFlight/App Store upload must be done from macOS/Xcode.
