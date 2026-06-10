# Releasing AwayLock

This document is for maintainers preparing preview or signed release builds.

## Build a Local `.app`

```sh
./scripts/build_app.sh
open dist/AwayLock.app
```

By default, local builds are ad-hoc signed.

To build with a Developer ID Application certificate:

```sh
SIGN_IDENTITY="Developer ID Application: Leos Rehacek (TEAMID)" CODESIGN_TIMESTAMP=1 ./scripts/build_app.sh
```

## Build a Release ZIP

```sh
./scripts/package_release.sh
```

The ZIP is written to `dist/AwayLock-preview.zip`.

## Notarize a Release ZIP

```sh
SIGN_IDENTITY="Developer ID Application: Leos Rehacek (TEAMID)" \
CODESIGN_TIMESTAMP=1 \
NOTARIZE=1 \
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_PASSWORD="app-specific-password" \
./scripts/package_release.sh
```
