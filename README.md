# Mochy Music iOS

Native SwiftUI iPhone port of Mochy Music 8.3.2 (build 1225).

## Build

Requirements: macOS with Xcode 16 or newer and an iOS 17 SDK.

```sh
cd ios
./scripts/build-ipa.sh Release
```

The unsigned IPA is written to `ios/build/Mochy.ipa`. It can be signed and installed with SideStore, AltStore, or another sideloading tool.

## CI

GitHub Actions builds only the unsigned iOS IPA (`workflow_dispatch` or push to `main`) and uploads it as the `Mochy-unsigned-ipa` artifact. No Android/APK build is performed in this repository.

## License

GPL-3.0. See `LICENSE`.
