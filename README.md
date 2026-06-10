# AwayLock

AwayLock is a native macOS menu bar app that watches a selected Bluetooth LE device and locks the Mac when the device is missing or has a weak averaged RSSI signal for longer than the configured timeout.

AwayLock is free. If you find it useful, the app includes an optional Buy Me a Coffee link for supporting development.

> Preview status: AwayLock is currently an unsigned preview build. Public notarized distribution requires an Apple Developer Program membership.

## Features

- Menu bar-only app using AppKit and SwiftUI.
- CoreBluetooth scanning with selection limited to devices already paired or known to this Mac.
- Stored selected device in `UserDefaults`.
- RSSI moving average with configurable window.
- Missing-device and weak-signal lock timeouts.
- Pause, enable/disable, cooldown, notifications, logs, and settings.
- Modern light/dark/system appearance setting.
- Launch at Login wiring through `SMAppService.mainApp`.

## Download

For now, download preview builds from GitHub Releases.

Because preview builds are not notarized yet, macOS may block opening the app the first time. Use right-click > Open, then confirm that you want to open it.

## Website

The GitHub Pages landing page lives in `docs/`.

After pushing the repository, enable GitHub Pages in Settings > Pages and choose:

- Source: Deploy from a branch
- Branch: `main`
- Folder: `/docs`

The site will be available at `https://leosrehacek.github.io/AwayLock/`.

## Run From Source

```sh
swift run AwayLock
```

## Build a `.app` Bundle

```sh
./scripts/build_app.sh
open dist/AwayLock.app
```

By default, local builds are ad-hoc signed. After you have a paid Apple Developer Program membership and a Developer ID Application certificate installed in Keychain, build with:

```sh
SIGN_IDENTITY="Developer ID Application: Leos Rehacek (TEAMID)" CODESIGN_TIMESTAMP=1 ./scripts/build_app.sh
```

AwayLock locks the current macOS session directly. It sends the macOS lock shortcut from the app and falls back to system commands when available; it does not use display sleep. Grant AwayLock Accessibility permission in System Settings > Privacy & Security > Accessibility if Lock Now logs that permission is required. If macOS asks whether AwayLock can control System Events, allow it.

## Build a Release ZIP

```sh
./scripts/package_release.sh
```

The ZIP is written to `dist/AwayLock-preview.zip`.

To notarize a signed release ZIP later:

```sh
SIGN_IDENTITY="Developer ID Application: Leos Rehacek (TEAMID)" \
CODESIGN_TIMESTAMP=1 \
NOTARIZE=1 \
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_PASSWORD="app-specific-password" \
./scripts/package_release.sh
```

## Bluetooth Note

CoreBluetooth scans Bluetooth LE advertisements. The selection window filters those scan results against devices already paired or known to this Mac through IOBluetooth. Pair the phone, watch, headphones, or other target in macOS Bluetooth settings first; classic Bluetooth devices may still not appear unless they advertise over BLE.

## Privacy

AwayLock scans local Bluetooth LE advertisements on your Mac. It does not upload device names, identifiers, RSSI values, logs, or settings to any server.

## Support

AwayLock is free. Optional support: https://buymeacoffee.com/leosrehacek
