# AnimeVsub iOS

UIKit MVP targeting **iOS 10.0**, intended for older iPhone models. The project avoids SwiftUI and third-party runtime dependencies.

## Generate the Xcode project

From this directory:

```bash
xcodegen generate
open AnimeVsub.xcodeproj
```

The client follows the desktop-web API contract: HTML pages plus POST routes
`/ajax/item`, `/ajax/suggest`, `/ajax/player` and `/ajax/player?v=2019a`.
The host is configurable through `APIClient.shared.baseURL`; the default is
`https://animevietsub.xyz` and can be changed in the app. The Android
`api_hidden` submodule is empty in this
checkout, so the host may need to be changed to the currently active mirror.

## Current MVP

- UIKit tab navigation
- Low-memory `UICollectionView` poster grid
- Cached poster images with `NSCache`
- Home data, search, detail and HLS player abstractions
- iOS 10 deployment target

The downloader first reads a normal HLS playlist, resolves master-playlist
variants, and downloads clear segments one by one while reporting progress.
Iframe links and encrypted/custom-transformed HLS are reported as unsupported;
the Android app's hidden segment transformation cannot be reproduced from the
public checkout without the corresponding authorized implementation.

## Unsigned IPA for a jailbroken iPhone

The workflow at `../.github/workflows/ios-build.yml` builds an unsigned IPA
without an Apple certificate or provisioning profile. This is intentional for
devices with AppSync. Run it from GitHub Actions and download the
`AnimeVsub-unsigned.ipa` artifact. Install it with the jailbreak package
installer/sideload tool you already use. AppSync bypasses Apple's normal
signature requirement, but it does not bypass an app's minimum iOS version or
runtime/API incompatibilities.

## iPhone is not shown in Xcode

The phone must be unlocked, trusted, and connected by a data-capable cable.
On the Mac, `xcrun xcode-select -p` must point to the full Xcode bundle, not
`/Library/Developer/CommandLineTools`:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Then open Xcode, accept the trust prompt on the iPhone, enable **Developer Mode**
if the iOS version provides it, and select the phone under **Window > Devices
and Simulators**. An iOS 10–12 phone may require an older Xcode/device-support
image; a modern Xcode can archive the app but may not be able to run directly
on every old iOS device.
