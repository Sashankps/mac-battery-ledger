# mac-battery-ledger

mac-battery-ledger is a native macOS menu bar app for MacBooks. It replaces the default battery percentage menu item with a compact battery icon and percent, then opens a clean SwiftUI panel with charge history, discharge history, cycle count, health, capacity, and live battery status.

## Build

```sh
./Scripts/build-app.sh
```

The app bundle is created at:

```sh
.build/mac-battery-ledger.app
```

To install the Finder-launchable app into Applications:

```sh
./Scripts/build-app.sh --install
```

This creates:

```sh
/Applications/Mac Battery Ledger.app
```

## Download a release

Download the latest `Mac-Battery-Ledger-X.Y.Z.zip` from the repository's
[Releases](https://github.com/Sashankps/mac-battery-ledger/releases) page.

The release is ad-hoc signed, not Apple-notarized. On first launch, macOS may
require you to Control-click the app, choose **Open**, and confirm.

## Publish a release

1. On `main`, update `VERSION` using the `X.Y.Z` format and commit the change.
2. Create and push a matching tag from that commit:

   ```sh
   VERSION="$(tr -d '[:space:]' < VERSION)"
   git tag "v$VERSION"
   git push origin "v$VERSION"
   ```

GitHub Actions builds the app, creates a ZIP archive and SHA-256 checksum, and
publishes both files in a GitHub Release with generated release notes.

To build the same release archive locally:

```sh
./Scripts/package-release.sh
```

The files are created in `dist/`.

## Run during development

```sh
swift run mac-battery-ledger
```

## History

The app stores observed charge and discharge sessions in:

```text
~/Library/Application Support/mac-battery-ledger/history.json
```

A charge session starts while power is connected. A discharge session starts when power is removed and ends when the next charge begins.
